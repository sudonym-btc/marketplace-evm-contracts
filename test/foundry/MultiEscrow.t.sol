// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MultiEscrow} from "../../contracts/MultiEscrow.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function deal(address account, uint256 newBalance) external;
    function expectRevert(bytes4 revertData) external;
    function prank(address msgSender) external;
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function warp(uint256 newTimestamp) external;
}

contract FalseToken {
    mapping(address => uint256) public balanceOf;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}

contract MultiEscrowTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant RELEASE_TYPEHASH = keccak256("Release(bytes32 tradeId,address actor)");
    bytes32 private constant CLAIM_TYPEHASH = keccak256("Claim(bytes32 tradeId)");
    bytes32 private constant ARBITRATE_TYPEHASH =
        keccak256("Arbitrate(bytes32 tradeId,uint256 paymentFactor,uint256 bondFactor)");
    bytes32 private constant WITHDRAW_TYPEHASH = keccak256("Withdraw(address token,address destination,uint256 nonce)");

    uint256 private constant BUYER_KEY = 0xA11CE;
    uint256 private constant SELLER_KEY = 0xB0B;
    uint256 private constant ARBITER_KEY = 0xA8B17E2;

    MultiEscrow private escrow;
    address private buyer;
    address private seller;
    address private arbiter;

    function setUp() public {
        buyer = vm.addr(BUYER_KEY);
        seller = vm.addr(SELLER_KEY);
        arbiter = vm.addr(ARBITER_KEY);
        escrow = new MultiEscrow();
    }

    function _digest(bytes32 structHash) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("Nostr MultiEscrow")),
                keccak256(bytes("6")),
                block.chainid,
                address(escrow)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function _signature(uint256 key, bytes32 structHash) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, _digest(structHash));
        return abi.encodePacked(r, s, v);
    }

    function _create(bytes32 tradeId, uint256 payment, uint256 bond, uint256 fee, uint256 unlockAt) private {
        vm.deal(buyer, payment + bond);
        vm.prank(buyer);
        escrow.createTrade{value: payment + bond}(
            tradeId, buyer, seller, arbiter, address(0), payment, bond, unlockAt, fee
        );
    }

    function _releaseByBuyer(bytes32 tradeId) private {
        bytes memory signature = _signature(BUYER_KEY, keccak256(abi.encode(RELEASE_TYPEHASH, tradeId, buyer)));
        escrow.releaseToCounterparty(tradeId, buyer, signature);
    }

    function testCreateReleaseAndWithdrawNative() public {
        bytes32 tradeId = keccak256("release");
        _create(tradeId, 1 ether, 0, 0.01 ether, block.timestamp + 1 days);

        require(escrow.activeTradeCount() == 1, "active count");
        _releaseByBuyer(tradeId);
        require(escrow.activeTradeCount() == 0, "settled active count");
        require(escrow.balances(seller, address(0)) == 0.99 ether, "seller credit");
        require(escrow.balances(arbiter, address(0)) == 0.01 ether, "arbiter fee");

        uint256 beforeBalance = seller.balance;
        vm.prank(seller);
        escrow.withdraw(address(0), seller, seller, "");
        require(seller.balance - beforeBalance == 0.99 ether, "withdraw amount");
        require(escrow.withdrawNonces(seller) == 1, "withdraw nonce");
    }

    function testTimeoutClaimUsesConfiguredClaimant() public {
        bytes32 tradeId = keccak256("claim");
        uint256 unlockAt = block.timestamp + 10;
        _create(tradeId, 2 ether, 0.5 ether, 0, unlockAt);
        vm.warp(unlockAt + 1);

        bytes memory signature = _signature(SELLER_KEY, keccak256(abi.encode(CLAIM_TYPEHASH, tradeId)));
        escrow.claim(tradeId, signature);
        require(escrow.balances(seller, address(0)) == 2 ether, "seller payment");
        require(escrow.balances(buyer, address(0)) == 0.5 ether, "buyer bond");
    }

    function testRelayedWithdrawalSignatureCannotDrainFutureBalance() public {
        bytes32 firstId = keccak256("withdraw-one");
        _create(firstId, 1 ether, 0, 0, block.timestamp + 1 days);
        _releaseByBuyer(firstId);

        bytes memory signature =
            _signature(SELLER_KEY, keccak256(abi.encode(WITHDRAW_TYPEHASH, address(0), seller, uint256(0))));
        escrow.withdraw(address(0), seller, seller, signature);

        bytes32 secondId = keccak256("withdraw-two");
        _create(secondId, 1 ether, 0, 0, block.timestamp + 1 days);
        _releaseByBuyer(secondId);

        vm.expectRevert(MultiEscrow.InvalidSignature.selector);
        escrow.withdraw(address(0), seller, seller, signature);
    }

    function testFuzzArbitrationConservesValue(
        uint96 rawPayment,
        uint96 rawBond,
        uint16 rawPaymentFactor,
        uint16 rawBondFactor
    ) public {
        uint256 payment = uint256(rawPayment) % 100 ether + 1;
        uint256 bond = uint256(rawBond) % 100 ether;
        uint256 paymentFactor = uint256(rawPaymentFactor) % 1001;
        uint256 bondFactor = uint256(rawBondFactor) % 1001;
        bytes32 tradeId = keccak256(abi.encode(rawPayment, rawBond, rawPaymentFactor, rawBondFactor));

        _create(tradeId, payment, bond, 0, block.timestamp + 1 days);
        bytes memory signature =
            _signature(ARBITER_KEY, keccak256(abi.encode(ARBITRATE_TYPEHASH, tradeId, paymentFactor, bondFactor)));
        escrow.arbitrate(tradeId, paymentFactor, bondFactor, signature);

        uint256 credited = escrow.balances(seller, address(0)) + escrow.balances(buyer, address(0))
            + escrow.balances(arbiter, address(0));
        require(credited == payment + bond, "value not conserved");
        require(escrow.totalPending(address(0)) == payment + bond, "pending mismatch");
    }

    function testRejectsInvalidParticipantsAndOwnership() public {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        vm.expectRevert(MultiEscrow.InvalidAddress.selector);
        escrow.createTrade{value: 1 ether}(
            keccak256("zero buyer"), address(0), seller, arbiter, address(0), 1 ether, 0, block.timestamp + 1, 0
        );

        vm.expectRevert(MultiEscrow.InvalidAddress.selector);
        escrow.transferOwnership(address(0));
    }

    function testRejectsFalseReturningToken() public {
        FalseToken token = new FalseToken();
        token.mint(buyer, 100);
        vm.prank(buyer);
        vm.expectRevert(MultiEscrow.ERC20TransferFailed.selector);
        escrow.createTrade(
            keccak256("false token"), buyer, seller, arbiter, address(token), 100, 0, block.timestamp + 1, 0
        );
    }

    function testNativeRescueCannotTakeCommittedFunds() public {
        _create(keccak256("committed"), 1 ether, 0, 0, block.timestamp + 1 days);
        vm.expectRevert(MultiEscrow.InsufficientExcess.selector);
        escrow.rescueNative(payable(address(this)), 1);

        vm.deal(address(escrow), address(escrow).balance + 0.25 ether);
        uint256 beforeBalance = address(this).balance;
        escrow.rescueNative(payable(address(this)), 0.25 ether);
        require(address(this).balance - beforeBalance == 0.25 ether, "native rescue");
    }

    receive() external payable {}
}
