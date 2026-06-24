# Marketplace EVM Contracts

Shared marketplace escrow contract artifacts for Sudonym marketplace packages.

## Docs

Package-owned docs live in [`docs`](docs/README.md). Start with
[`docs/getting-started.md`](docs/getting-started.md) and regenerate the API
reference with:

```sh
npm run docs:api
```

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
} from '@sudonym-btc/marketplace-evm-contracts'
```

Raw artifacts are also exported:

- `@sudonym-btc/marketplace-evm-contracts/artifacts/MultiEscrow.json`
- `@sudonym-btc/marketplace-evm-contracts/artifacts/MultiEscrow.abi.json`
- `@sudonym-btc/marketplace-evm-contracts/contracts/MultiEscrow.sol`

## Updating Contract Sources

When the `MultiEscrow` contract changes in a source checkout, run:

```sh
MULTI_ESCROW_SOURCE=/path/to/marketplace-source/contracts/MultiEscrow.sol \
MULTI_ESCROW_ARTIFACT=/path/to/marketplace-source/artifacts/contracts/MultiEscrow.sol/MultiEscrow.json \
npm run sync:multi-escrow
```

That updates the Solidity source, artifact JSON, ABI JSON, generated TypeScript,
and runtime bytecode hash registry in one commit. Downstream packages then bump
their dependency to the new contracts commit/tag.
