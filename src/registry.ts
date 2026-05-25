import {
  multiEscrowAbi,
  multiEscrowBytecode,
  multiEscrowDeployedBytecode,
  multiEscrowRuntimeBytecodeHash,
} from './multiEscrow.js'

export type MarketplaceContractArtifact = {
  readonly name: string
  readonly version: string
  readonly sourceName: string
  readonly abi: readonly unknown[]
  readonly bytecode: `0x${string}`
  readonly deployedBytecode: `0x${string}`
  readonly runtimeBytecodeHash: `0x${string}`
}

export const multiEscrowContract = {
  name: "MultiEscrow",
  version: "0.1.0",
  sourceName: "contracts/MultiEscrow.sol",
  abi: multiEscrowAbi,
  bytecode: multiEscrowBytecode,
  deployedBytecode: multiEscrowDeployedBytecode,
  runtimeBytecodeHash: multiEscrowRuntimeBytecodeHash,
} satisfies MarketplaceContractArtifact

export const multiEscrowRegistry = {
  [multiEscrowRuntimeBytecodeHash]: multiEscrowContract,
} as const

export function findMultiEscrowByRuntimeBytecodeHash(
  runtimeBytecodeHash: string | null | undefined,
): MarketplaceContractArtifact | undefined {
  if (!runtimeBytecodeHash) return undefined
  return multiEscrowRegistry[runtimeBytecodeHash.toLowerCase() as keyof typeof multiEscrowRegistry]
}
