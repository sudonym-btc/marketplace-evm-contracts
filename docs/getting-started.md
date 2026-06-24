# Getting started with Marketplace EVM Contracts

`@sudonym-btc/marketplace-evm-contracts` is the source of truth for the
`MultiEscrow` Solidity source, ABI artifacts, generated TypeScript exports, and
runtime bytecode hash registry used by the EVM marketplace driver.

## Install

```sh
npm install @sudonym-btc/marketplace-evm-contracts
```

## Import contract metadata

```ts
import {
  multiEscrowAbi,
  multiEscrowContract,
  multiEscrowRuntimeBytecodeHash,
  findMultiEscrowByRuntimeBytecodeHash,
} from '@sudonym-btc/marketplace-evm-contracts'
```

## Update generated artifacts

When the Solidity source or upstream build artifact changes, sync and rebuild
the package-owned generated files:

```sh
MULTI_ESCROW_SOURCE=/path/to/source/contracts/MultiEscrow.sol \
MULTI_ESCROW_ARTIFACT=/path/to/source/artifacts/contracts/MultiEscrow.sol/MultiEscrow.json \
npm run sync:multi-escrow
```

Read the generated [API reference](reference/README.md) for exported ABI,
contract, and runtime bytecode registry values.
