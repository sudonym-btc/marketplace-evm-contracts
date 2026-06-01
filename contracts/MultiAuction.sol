// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAuctionERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract MultiAuction is EIP712, ReentrancyGuard {
    address public owner;

    error OnlyOwner();
    error InvalidSignature();
    error NotAContract();
    error AuctionAlreadySettled();
    error AuctionEnded();
    error AuctionNotEnded();
    error AuctionNotFound();
    error AuctionParamsChanged();
    error BidTooLow();
    error EscrowFeeTooHigh();
    error InvalidBidder();
    error MustSendExactNativeAmount();
    error NativeTransferFailed();
    error ERC20TransferFailed();
    error NothingToWithdraw();

    struct Auction {
        address seller;
        address arbiter;
        address token;
        address highestBidder;
        uint256 highestBid;
        uint256 endsAt;
        uint256 escrowFee;
        bool settled;
    }

    bytes32 private constant SETTLE_TYPEHASH =
        keccak256("Settle(bytes32 auctionId)");

    bytes32 private constant CANCEL_TYPEHASH =
        keccak256("Cancel(bytes32 auctionId)");

    bytes32 private constant WITHDRAW_TYPEHASH =
        keccak256("Withdraw(address token,address destination)");

    mapping(bytes32 => Auction) public auctions;

    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => address[]) private _userTokens;
    mapping(address => mapping(address => bool)) private _userTokenKnown;
    mapping(address => uint256) public totalPending;

    event AuctionCreated(bytes32 indexed auctionId, address indexed token, address seller, address indexed arbiter, uint256 endsAt, uint256 escrowFee);
    event BidPlaced(bytes32 indexed auctionId, address indexed bidder, address indexed token, uint256 amount, address previousBidder, uint256 previousBid);
    event AuctionCancelled(bytes32 indexed auctionId, address indexed token, address highestBidder, uint256 highestBid);
    event AuctionSettled(bytes32 indexed auctionId, address indexed token, address seller, address highestBidder, uint256 highestBid, uint256 escrowFee);
    event Withdrawn(address indexed beneficiary, address indexed token, address destination, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() EIP712("Hostr MultiAuction", "1") {
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    function _verifySigner(address signer, bytes32 structHash, bytes calldata signature) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);
        if (!SignatureChecker.isValidSignatureNow(signer, digest, signature)) {
            revert InvalidSignature();
        }
    }

    function _transfer(address token, address recipient, uint256 amount) internal {
        if (amount == 0) return;

        if (token == address(0)) {
            (bool success,) = payable(recipient).call{value: amount}("");
            if (!success) revert NativeTransferFailed();
        } else {
            if (token.code.length == 0) revert NotAContract();
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSelector(IAuctionERC20.transfer.selector, recipient, amount)
            );
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert ERC20TransferFailed();
            }
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        if (token.code.length == 0) revert NotAContract();
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IAuctionERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert ERC20TransferFailed();
        }
    }

    function _creditBalance(address recipient, address token, uint256 amount) internal {
        if (amount == 0 || recipient == address(0)) return;
        balances[recipient][token] += amount;
        if (!_userTokenKnown[recipient][token]) {
            _userTokenKnown[recipient][token] = true;
            _userTokens[recipient].push(token);
        }
        totalPending[token] += amount;
    }

    function _takeBidFunds(address token, address bidder, uint256 amount) internal {
        if (token == address(0)) {
            if (msg.value != amount) revert MustSendExactNativeAmount();
        } else {
            if (msg.value != 0) revert MustSendExactNativeAmount();
            _safeTransferFrom(token, bidder, address(this), amount);
        }
    }

    function placeBid(
        bytes32 auctionId,
        address bidder,
        address seller,
        address arbiter,
        address token,
        uint256 amount,
        uint256 endsAt,
        uint256 escrowFee
    ) external payable nonReentrant {
        if (bidder == address(0)) revert InvalidBidder();
        if (block.timestamp >= endsAt) revert AuctionEnded();
        if (escrowFee > amount) revert EscrowFeeTooHigh();

        Auction storage auction = auctions[auctionId];
        if (auction.seller == address(0)) {
            auction.seller = seller;
            auction.arbiter = arbiter;
            auction.token = token;
            auction.endsAt = endsAt;
            auction.escrowFee = escrowFee;
            emit AuctionCreated(auctionId, token, seller, arbiter, endsAt, escrowFee);
        } else {
            if (auction.settled) revert AuctionAlreadySettled();
            if (
                auction.seller != seller ||
                auction.arbiter != arbiter ||
                auction.token != token ||
                auction.endsAt != endsAt ||
                auction.escrowFee != escrowFee
            ) {
                revert AuctionParamsChanged();
            }
        }

        if (amount <= auction.highestBid) revert BidTooLow();

        address previousBidder = auction.highestBidder;
        uint256 previousBid = auction.highestBid;
        _takeBidFunds(token, bidder, amount);

        auction.highestBidder = bidder;
        auction.highestBid = amount;

        if (previousBid > 0) {
            _creditBalance(previousBidder, token, previousBid);
        }

        emit BidPlaced(auctionId, bidder, token, amount, previousBidder, previousBid);
    }

    function cancel(bytes32 auctionId, bytes calldata signature) external nonReentrant {
        Auction memory auction = auctions[auctionId];
        if (auction.seller == address(0)) revert AuctionNotFound();
        if (auction.settled) revert AuctionAlreadySettled();
        _verifySigner(auction.arbiter, keccak256(abi.encode(CANCEL_TYPEHASH, auctionId)), signature);

        delete auctions[auctionId];
        _creditBalance(auction.highestBidder, auction.token, auction.highestBid);

        emit AuctionCancelled(auctionId, auction.token, auction.highestBidder, auction.highestBid);
    }

    function settle(bytes32 auctionId, bytes calldata signature) external nonReentrant {
        Auction memory auction = auctions[auctionId];
        if (auction.seller == address(0)) revert AuctionNotFound();
        if (auction.settled) revert AuctionAlreadySettled();
        if (block.timestamp < auction.endsAt) revert AuctionNotEnded();
        _verifySigner(auction.arbiter, keccak256(abi.encode(SETTLE_TYPEHASH, auctionId)), signature);

        delete auctions[auctionId];

        uint256 sellerAmount = auction.highestBid - auction.escrowFee;
        _creditBalance(auction.seller, auction.token, sellerAmount);
        _creditBalance(auction.arbiter, auction.token, auction.escrowFee);

        emit AuctionSettled(auctionId, auction.token, auction.seller, auction.highestBidder, auction.highestBid, auction.escrowFee);
    }

    function withdraw(address token, address beneficiary, address destination, bytes calldata signature) external nonReentrant {
        _verifySigner(beneficiary, keccak256(abi.encode(WITHDRAW_TYPEHASH, token, destination)), signature);

        uint256 amount = balances[beneficiary][token];
        if (amount == 0) revert NothingToWithdraw();

        balances[beneficiary][token] = 0;
        totalPending[token] -= amount;
        _transfer(token, destination, amount);

        emit Withdrawn(beneficiary, token, destination, amount);
    }

    function userTokens(address user) external view returns (address[] memory) {
        return _userTokens[user];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
