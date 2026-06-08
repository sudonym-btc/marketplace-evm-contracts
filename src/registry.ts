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

export const marketplaceContractRegistry = {
  [multiEscrowRuntimeBytecodeHash]: multiEscrowContract,
} as const

export function findMultiEscrowByRuntimeBytecodeHash(
  runtimeBytecodeHash: string | null | undefined,
): MarketplaceContractArtifact | undefined {
  if (!runtimeBytecodeHash) return undefined
  const normalized = runtimeBytecodeHash.toLowerCase()
  return normalized === multiEscrowRuntimeBytecodeHash ? multiEscrowContract : undefined
}

export function findMarketplaceContractByRuntimeBytecodeHash(
  runtimeBytecodeHash: string | null | undefined,
): MarketplaceContractArtifact | undefined {
  if (!runtimeBytecodeHash) return undefined
  return marketplaceContractRegistry[runtimeBytecodeHash.toLowerCase() as keyof typeof marketplaceContractRegistry]
}
