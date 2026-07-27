import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const packageRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const aggregateRoot = path.resolve(packageRoot, '../..')
const localOpenZeppelin = path.join(packageRoot, 'node_modules/@openzeppelin')
const hoistedOpenZeppelin = path.join(aggregateRoot, 'node_modules/@openzeppelin')
const dependencyRoot = existsSync(localOpenZeppelin)
  ? localOpenZeppelin
  : existsSync(hoistedOpenZeppelin)
    ? hoistedOpenZeppelin
    : null

if (!dependencyRoot) {
  throw new Error('OpenZeppelin sources are missing; run npm ci before Solidity tests')
}

const localForge = spawnSync('forge', ['--version'], { stdio: 'ignore' }).status === 0
if (localForge) {
  const format = spawnSync('forge', ['fmt', '--check'], { cwd: packageRoot, stdio: 'inherit' })
  if (format.status !== 0) process.exit(format.status ?? 1)
  const result = spawnSync('forge', [
    'test',
    '--remappings',
    `@openzeppelin/=${dependencyRoot}/`,
  ], { cwd: packageRoot, stdio: 'inherit' })
  process.exit(result.status ?? 1)
}

const usesAggregate = dependencyRoot === hoistedOpenZeppelin
const mountRoot = usesAggregate ? aggregateRoot : packageRoot
const workdir = usesAggregate ? '/workspace/dependencies/marketplace-evm-contracts' : '/workspace'
const containerDependency = usesAggregate
  ? '/workspace/node_modules/@openzeppelin/'
  : '/workspace/node_modules/@openzeppelin/'
const image = 'boltz/foundry@sha256:790a32fde1bc937e6c0ecfa9df0c37dbae5c940c1f97b20cc27a22cc3d080a5f'
const dockerBase = [
  'run', '--rm', '--platform', 'linux/amd64',
  '-v', `${mountRoot}:/workspace`,
  '-w', workdir,
  image,
]
const format = spawnSync('docker', [...dockerBase, 'forge', 'fmt', '--check'], { stdio: 'inherit' })
if (format.status !== 0) process.exit(format.status ?? 1)
const result = spawnSync('docker', [
  ...dockerBase, 'forge', 'test', '--remappings', `@openzeppelin/=${containerDependency}`,
], { stdio: 'inherit' })
process.exit(result.status ?? 1)
