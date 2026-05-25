import { copyFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { pathToFileURL } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const sourcePath = process.env.MULTI_ESCROW_SOURCE
const artifactPath = process.env.MULTI_ESCROW_ARTIFACT

if (!sourcePath) {
  throw new Error('Set MULTI_ESCROW_SOURCE to the source MultiEscrow.sol path')
}
if (!artifactPath) {
  throw new Error('Set MULTI_ESCROW_ARTIFACT to the compiled Hardhat MultiEscrow.json artifact path')
}

copyFileSync(sourcePath, join(root, 'contracts', 'MultiEscrow.sol'))
copyFileSync(artifactPath, join(root, 'artifacts', 'MultiEscrow.json'))

await import(pathToFileURL(join(root, 'scripts', 'generate.mjs')).href)

