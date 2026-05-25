import assert from 'node:assert/strict'
import { test } from 'node:test'

import {
  findMultiEscrowByRuntimeBytecodeHash,
  multiEscrowAbi,
  multiEscrowContract,
  multiEscrowRuntimeBytecodeHash,
} from '../dist/index.js'

test('exports the generated MultiEscrow artifact and bytecode registry', () => {
  const tradeCreated = multiEscrowAbi.find(entry => entry.type === 'event' && entry.name === 'TradeCreated')
  assert.ok(tradeCreated)
  assert.equal(tradeCreated.inputs[2].name, 'seller')
  assert.equal(tradeCreated.inputs[3].name, 'buyer')
  assert.equal(tradeCreated.inputs[4].name, 'arbiter')

  assert.equal(multiEscrowContract.name, 'MultiEscrow')
  assert.equal(multiEscrowContract.runtimeBytecodeHash, multiEscrowRuntimeBytecodeHash)
  assert.equal(findMultiEscrowByRuntimeBytecodeHash(multiEscrowRuntimeBytecodeHash)?.name, 'MultiEscrow')
  assert.equal(findMultiEscrowByRuntimeBytecodeHash('0xdeadbeef'), undefined)
})

