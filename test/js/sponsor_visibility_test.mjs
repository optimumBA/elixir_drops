import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
const source = await readFile(new URL('../../assets/js/hooks/sponsor_impression.js', import.meta.url), 'utf8')
const { PlacementReporter, VisibilityReporter } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)

function environment(t) {
  let now = 0, nextId = 0
  const timers = new Map(), listeners = new Map(), observers = []
  const previous = Object.fromEntries(['setTimeout', 'clearTimeout', 'document', 'window', 'IntersectionObserver'].map(k => [k, globalThis[k]]))
  globalThis.setTimeout = (fn, ms) => { const id = ++nextId; timers.set(id, { fn, at: now + ms }); return id }
  globalThis.clearTimeout = id => timers.delete(id)
  globalThis.window = { innerWidth: 1000, innerHeight: 800 }
  globalThis.document = {
    visibilityState: 'visible',
    addEventListener: (name, cb) => listeners.set(name, cb),
    removeEventListener: name => listeners.delete(name),
  }
  globalThis.IntersectionObserver = class {
    constructor(cb) { this.cb = cb; observers.push(this) }
    observe() {}
    disconnect() {}
  }
  t.after(() => Object.assign(globalThis, previous))
  const microtasks = async () => { for (let i = 0; i < 8; i++) await Promise.resolve() }
  return {
    async tick(ms) {
      await microtasks()
      const end = now + ms
      while (true) {
        const next = [...timers].filter(([, v]) => v.at <= end).sort((a,b) => a[1].at - b[1].at)[0]
        if (!next) break
        now = next[1].at; timers.delete(next[0]); next[1].fn(); await microtasks()
      }
      now = end; await microtasks()
    },
    intersect(el, ratio) { observers.at(-1).cb([{ target: el, intersectionRatio: ratio }]) },
    background(hidden) { document.visibilityState = hidden ? 'hidden' : 'visible'; listeners.get('visibilitychange')?.() },
    timers,
  }
}
const rect = (top = 20) => ({ top, left: 20, right: 220, bottom: top + 200, width: 200, height: 200 })

test('partial acknowledgment retries only the failed placement without waiting for a resize', async t => {
  const env = environment(t), batches = []
  const reporter = new PlacementReporter({ rendered: () => ['banner', 'sidebar'], send: async placements => {
    batches.push(placements)
    return { acknowledged: batches.length === 1 ? ['banner'] : placements }
  } })
  reporter.flush(); await env.tick(0)
  assert.deepEqual(batches, [['banner', 'sidebar']])
  await env.tick(1000)
  assert.deepEqual(batches, [['banner', 'sidebar'], ['sidebar']])
  reporter.setConnected(false); reporter.setConnected(true); reporter.flush()
  await env.tick(10000)
  assert.equal(batches.length, 2)
  reporter.stop()
})

test('lost replies time out, retry boundedly and stop at three attempts', async t => {
  const env = environment(t); let attempts = 0
  const reporter = new PlacementReporter({ rendered: () => ['banner'], send: () => { attempts++; return new Promise(() => {}) } })
  reporter.flush(); await env.tick(30000)
  reporter.setConnected(false); reporter.setConnected(true)
  await env.tick(30000)
  assert.equal(attempts, 3)
  reporter.stop()
  assert.equal(env.timers.size, 0)
})

test('visible estimate requires a continuous foreground second and resets background dwell', async t => {
  const env = environment(t), el = { getBoundingClientRect: () => rect() }; let sends = 0
  const visibility = new VisibilityReporter({ targets: new Map([['banner', el]]), send: async placements => { sends++; return { acknowledged: placements } } })
  env.intersect(el, 0.6); await env.tick(600)
  env.background(true); await env.tick(2000)
  assert.equal(sends, 0)
  env.background(false); await env.tick(999)
  assert.equal(sends, 0)
  await env.tick(1)
  assert.equal(sends, 1)
  visibility.setConnected(false); visibility.setConnected(true); env.intersect(el, 1)
  await env.tick(2000)
  assert.equal(sends, 1)
  visibility.stop()
})

test('below-fold and resize/reconnect interruptions cannot satisfy dwell', async t => {
  const env = environment(t); let box = rect(2000), sends = 0
  const el = { getBoundingClientRect: () => box }
  const visibility = new VisibilityReporter({ targets: new Map([['banner', el]]), send: async placements => { sends++; return { acknowledged: placements } } })
  env.intersect(el, 0); await env.tick(2000)
  assert.equal(sends, 0)
  box = rect(); env.intersect(el, 0.7); await env.tick(600)
  env.intersect(el, 0.4); await env.tick(600)
  env.intersect(el, 0.7); await env.tick(600)
  visibility.setConnected(false); await env.tick(1000)
  assert.equal(sends, 0)
  visibility.setConnected(true); await env.tick(999)
  assert.equal(sends, 0)
  await env.tick(1)
  assert.equal(sends, 1)
  visibility.stop()
})
