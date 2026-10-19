// Run: node --test test/js/sponsor_impression_test.mjs
// Uses node's built-in runner with fake timers and fake push replies; no
// browser, build step or new dependency.
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const source = await readFile(new URL('../../assets/js/hooks/sponsor_impression.js', import.meta.url), 'utf8')
const { PlacementReporter, MAX_ATTEMPTS, RETRY_DELAYS_MS, REPLY_TIMEOUT_MS } =
  await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)

function harness(replies, rendered = ['drop-banner', 'drop-sidebar']) {
  const ctx = { sent: [], rendered: [...rendered], replies: [...replies] }
  ctx.reporter = new PlacementReporter({
    rendered: () => ctx.rendered,
    send: (placements) => {
      ctx.sent.push([...placements])
      const next = ctx.replies.shift()
      return typeof next === 'function' ? next(placements) : Promise.resolve(next)
    },
  })
  return ctx
}

const settle = () => new Promise((resolve) => setImmediate(resolve))

test('acknowledged placements are never resent; resize/reconnect do not duplicate', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const h = harness([{ acknowledged: ['drop-banner', 'drop-sidebar'] }])
  h.reporter.flush()
  await settle()
  h.reporter.flush()
  h.reporter.setConnected(false)
  h.reporter.setConnected(true)
  await settle()
  assert.deepEqual(h.sent, [['drop-banner', 'drop-sidebar']])
})

test('partial failure retries only the unacknowledged placement on a timer', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const h = harness([
    { acknowledged: ['drop-banner'] },
    { acknowledged: ['drop-sidebar'] },
  ])
  h.reporter.flush()
  await settle()
  h.reporter.flush() // a resize inside the backoff window must not resend
  assert.equal(h.sent.length, 1)
  t.mock.timers.tick(RETRY_DELAYS_MS[0])
  await settle()
  assert.deepEqual(h.sent, [['drop-banner', 'drop-sidebar'], ['drop-sidebar']])
  t.mock.timers.tick(60000)
  await settle()
  assert.equal(h.sent.length, 2)
})

test('attempts are capped per placement', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const h = harness(Array(10).fill({ acknowledged: [] }), ['drop-banner'])
  h.reporter.flush()
  for (let i = 0; i < 6; i++) {
    await settle()
    t.mock.timers.tick(10000)
  }
  await settle()
  h.reporter.flush()
  assert.equal(h.sent.length, MAX_ATTEMPTS)
})

test('a lost reply times out, retries, and a late reply still acknowledges', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  let late
  const h = harness(
    [() => new Promise((resolve) => (late = resolve)), { acknowledged: ['drop-banner'] }],
    ['drop-banner'],
  )
  h.reporter.flush()
  t.mock.timers.tick(REPLY_TIMEOUT_MS)
  await settle()
  t.mock.timers.tick(RETRY_DELAYS_MS[0])
  await settle()
  assert.equal(h.sent.length, 2) // same stable server id makes this idempotent
  late({ acknowledged: ['drop-banner'] })
  await settle()
  t.mock.timers.tick(60000)
  assert.equal(h.sent.length, 2)
})

test('rejected push retries; disconnected waits for reconnect; stop clears timers', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const h = harness(
    [() => Promise.reject(new Error('down')), { acknowledged: ['drop-banner'] }],
    ['drop-banner'],
  )
  h.reporter.flush()
  await settle()
  h.reporter.setConnected(false)
  t.mock.timers.tick(RETRY_DELAYS_MS[0])
  await settle()
  assert.equal(h.sent.length, 1)
  h.reporter.setConnected(true)
  await settle()
  assert.equal(h.sent.length, 2)

  const g = harness([{ acknowledged: [] }], ['drop-banner'])
  g.reporter.flush()
  await settle()
  g.reporter.stop()
  t.mock.timers.tick(60000)
  await settle()
  assert.equal(g.sent.length, 1)
})

test('not-yet-rendered placements are not sent; a later reveal sends only it', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const h = harness(
    [{ acknowledged: ['drop-banner'] }, { acknowledged: ['drop-sidebar'] }],
    ['drop-banner'],
  )
  h.reporter.flush()
  await settle()
  h.rendered = ['drop-banner', 'drop-sidebar']
  h.reporter.flush()
  await settle()
  h.rendered = ['drop-banner']
  h.reporter.flush()
  h.rendered = ['drop-banner', 'drop-sidebar']
  h.reporter.flush()
  assert.deepEqual(h.sent, [['drop-banner'], ['drop-sidebar']])
})
