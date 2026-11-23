'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'private-drop-bookmarks'
const DIR = `features/steps/${P}__driver`
const LIVE_FILES = ['state_test.exs', 'list_test.exs', 'bound_test.exs', 'privacy_test.exs']
const BROWSER_FILES = ['browser_test.exs']
const cache = {}

// One ExUnit invocation runs all LiveView driver files and one runs the browser file, so the app
// boots twice instead of once per scenario; each scenario checks only its own named test.
function runGroup(browser) {
  const key = browser ? 'browser' : 'live'
  if (cache[key]) return cache[key]
  const files = browser ? BROWSER_FILES : LIVE_FILES
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const args = ['exec', '--', 'mix', 'test', '--trace']
  if (browser) args.push('--include', 'feature')
  args.push(...files.map((f) => `${DIR}/${f}`))
  const env = { ...process.env, MIX_ARCHIVES: archives }
  if (browser) env.FEATURE_TESTS = 'true'
  const result = spawnSync('mise', args, { cwd: process.cwd(), encoding: 'utf8', timeout: browser ? 50000 : 65000, maxBuffer: 64 * 1024 * 1024, env })
  const output = `${result.stdout || ''}${result.stderr || ''}`
  const summary = output.match(/(\d+) tests?, (\d+) failures?/)
  const failed = new Set()
  for (const m of output.matchAll(/^\s+\d+\) test (.+?) \(/gm)) failed.add(m[1])
  const ran = new Set()
  for (const m of output.matchAll(/^\s+\* test (.+?) \(\d/gm)) ran.add(m[1])
  cache[key] = { files, output, summary, failed, ran, status: result.status, signal: result.signal }
  return cache[key]
}

function assertPasses(file, name, browser) {
  const r = runGroup(browser)
  const context = `${P}: ran "mix test --trace ${browser ? '--include feature ' : ''}${r.files.map((f) => `${DIR}/${f}`).join(' ')}" (exit ${r.status}, signal ${r.signal}); output:\n${r.output.slice(-3000)}`
  assert.ok(r.summary, `${P}: no ExUnit summary line found (timeout or compile failure). ${context}`)
  assert.equal(Number(r.summary[1]), r.files.length, `${P}: expected ${r.files.length} tests to run (${file} among them). ${context}`)
  assert.ok(r.ran.has(name), `${P}: test "${name}" of ${file} did not run. ${context}`)
  assert.ok(!r.failed.has(name), `${P}: test "${name}" of ${file} failed. ${context}`)
}

Then(`${P}: the test file {string} runs its test {string} and it passes`, function (file, name) {
  assertPasses(file, name, false)
})

Then(`${P}: the browser test file {string} runs its test {string} and it passes`, function (file, name) {
  assertPasses(file, name, true)
})
