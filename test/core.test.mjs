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
  assert.equal(tradeCreated.inputs[8].name, 'timeoutClaimant')
  assert.equal(tradeCreated.inputs[10].name, 'contextHash')
  assert.equal(tradeCreated.inputs[11].name, 'recycleCovenantHash')

  const createTradeWithTerms = multiEscrowAbi.find(entry => entry.type === 'function' && entry.name === 'createTradeWithTerms')
  assert.ok(createTradeWithTerms)
  assert.equal(createTradeWithTerms.inputs.at(-1).name, 'recycleCovenantHash')

  const recycle = multiEscrowAbi.find(entry => entry.type === 'function' && entry.name === 'recycle')
  assert.ok(recycle)
  assert.equal(recycle.inputs[0].name, 'sourceTradeId')
  assert.equal(recycle.inputs[1].name, 'targetTradeId')
  assert.equal(recycle.inputs.at(-1).name, 'arbiterSignature')

  assert.equal(multiEscrowContract.name, 'MultiEscrow')
  assert.equal(multiEscrowContract.runtimeBytecodeHash, multiEscrowRuntimeBytecodeHash)
  assert.equal(findMultiEscrowByRuntimeBytecodeHash(multiEscrowRuntimeBytecodeHash)?.name, 'MultiEscrow')
  assert.equal(findMultiEscrowByRuntimeBytecodeHash('0xdeadbeef'), undefined)
})
