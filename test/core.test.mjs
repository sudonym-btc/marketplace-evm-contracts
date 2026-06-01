import assert from 'node:assert/strict'
import { test } from 'node:test'

import {
  findMultiAuctionByRuntimeBytecodeHash,
  findMultiEscrowByRuntimeBytecodeHash,
  multiAuctionAbi,
  multiAuctionContract,
  multiAuctionRuntimeBytecodeHash,
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

test('exports the generated MultiAuction artifact and bytecode registry', () => {
  const bidPlaced = multiAuctionAbi.find(entry => entry.type === 'event' && entry.name === 'BidPlaced')
  assert.ok(bidPlaced)
  assert.equal(bidPlaced.inputs[0].name, 'auctionId')
  assert.equal(bidPlaced.inputs[1].name, 'bidder')
  assert.equal(bidPlaced.inputs[2].name, 'token')

  const placeBid = multiAuctionAbi.find(entry => entry.type === 'function' && entry.name === 'placeBid')
  assert.ok(placeBid)

  assert.equal(multiAuctionContract.name, 'MultiAuction')
  assert.equal(multiAuctionContract.runtimeBytecodeHash, multiAuctionRuntimeBytecodeHash)
  assert.equal(findMultiAuctionByRuntimeBytecodeHash(multiAuctionRuntimeBytecodeHash)?.name, 'MultiAuction')
  assert.equal(findMultiAuctionByRuntimeBytecodeHash('0xdeadbeef'), undefined)
})
