import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import solc from 'solc'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const contracts = [
  { name: 'MultiEscrow', sourceName: 'contracts/MultiEscrow.sol' },
]
const artifactDir = join(root, 'artifacts')

function readImport(importPath) {
  const candidates = importPath.startsWith('@')
    ? [
        join(root, 'node_modules', importPath),
        join(root, '..', 'node_modules', importPath),
        join(root, '..', '..', 'node_modules', importPath),
      ]
    : [join(root, importPath)]
  for (const path of candidates) {
    try {
      return { contents: readFileSync(path, 'utf8') }
    } catch (_) {
      // try the next candidate
    }
  }
  return { error: `File not found: ${importPath}` }
}

const sources = Object.fromEntries(
  contracts.map(contract => [
    contract.sourceName,
    { content: readFileSync(join(root, contract.sourceName), 'utf8') },
  ]),
)

const input = {
  language: 'Solidity',
  sources,
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
    outputSelection: {
      '*': {
        '*': ['abi', 'evm.bytecode.object', 'evm.deployedBytecode.object'],
      },
    },
  },
}

const output = JSON.parse(solc.compile(JSON.stringify(input), { import: readImport }))
const errors = output.errors ?? []
const failures = errors.filter(error => error.severity === 'error')
for (const error of errors) {
  const stream = error.severity === 'error' ? process.stderr : process.stdout
  stream.write(`${error.formattedMessage}\n`)
}
if (failures.length > 0) process.exit(1)

mkdirSync(artifactDir, { recursive: true })
for (const contract of contracts) {
  const compiled = output.contracts?.[contract.sourceName]?.[contract.name]
  if (!compiled) throw new Error(`Missing compiled contract ${contract.name}`)
  const bytecode = compiled.evm.bytecode.object
  const deployedBytecode = compiled.evm.deployedBytecode.object
  writeFileSync(
    join(artifactDir, `${contract.name}.json`),
    `${JSON.stringify({
      contractName: contract.name,
      sourceName: contract.sourceName,
      abi: compiled.abi,
      bytecode: `0x${bytecode}`,
      deployedBytecode: `0x${deployedBytecode}`,
    }, null, 2)}\n`,
  )
}
