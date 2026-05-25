# Marketplace Contracts

Shared marketplace escrow contract artifacts for Sudonym marketplace packages.

This package is the source of truth for `MultiEscrow` Solidity source, Hardhat
artifact, ABI JSON, generated TypeScript exports, and runtime bytecode hashes.
Consumers should import ABI/registry data from this package instead of keeping
hand-written ABI copies.

## Exports

```ts
import {
  multiEscrowAbi,
  multiEscrowContract,
  multiEscrowRuntimeBytecodeHash,
  findMultiEscrowByRuntimeBytecodeHash,
} from '@sudonym-btc/marketplace-contracts'
```

Raw artifacts are also exported:

- `@sudonym-btc/marketplace-contracts/artifacts/MultiEscrow.json`
- `@sudonym-btc/marketplace-contracts/artifacts/MultiEscrow.abi.json`
- `@sudonym-btc/marketplace-contracts/contracts/MultiEscrow.sol`

## Updating From Hostr

When the `MultiEscrow` contract changes in the Hostr monorepo, run:

```sh
MULTI_ESCROW_SOURCE=/path/to/hostr/escrow/contracts/contracts/MultiEscrow.sol \
MULTI_ESCROW_ARTIFACT=/path/to/hostr/escrow/contracts/artifacts/contracts/MultiEscrow.sol/MultiEscrow.json \
npm run sync:multi-escrow
```

That updates the Solidity source, artifact JSON, ABI JSON, generated TypeScript,
and runtime bytecode hash registry in one commit. Downstream packages then bump
their dependency to the new contracts commit/tag.

