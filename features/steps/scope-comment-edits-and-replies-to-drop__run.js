'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'scope-comment-edits-and-replies-to-drop'
const FILE = `features/steps/${P}__driver/comment_write_scope_test.exs`
const EXPECTED_TESTS = 4
let cached = null

function runDriver() {
  if (cached) return cached
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const result = spawnSync('mise', ['exec', '--', 'mix', 'test', '--trace', FILE], {
    cwd: process.cwd(),
    encoding: 'utf8',
    timeout: 110000,
    env: { ...process.env, MIX_ARCHIVES: archives },
  })
  const output = `${result.stdout || ''}${result.stderr || ''}`
  const summary = output.match(/(\d+) tests?, (\d+) failures?/)
  const failed = new Set()
  for (const m of output.matchAll(/^\s+\d+\) test (.+?) \(/gm)) failed.add(m[1])
  const ran = new Set()
  for (const m of output.matchAll(/^\s+\* test (.+?) \(\d/gm)) ran.add(m[1])
  cached = { output, summary, failed, ran, status: result.status }
  return cached
}

Then(`${P}: the isolated test {string} passes`, function (name) {
  const r = runDriver()
  const context = `${P}: ran "mix test --trace ${FILE}" (exit ${r.status}); output:\n${r.output.slice(-3000)}`
  assert.ok(r.summary, `${P}: no ExUnit summary line found. ${context}`)
  assert.equal(Number(r.summary[1]), EXPECTED_TESTS, `${P}: expected ${EXPECTED_TESTS} tests to run. ${context}`)
  assert.ok(r.ran.has(name), `${P}: test "${name}" did not run. ${context}`)
  assert.ok(!r.failed.has(name), `${P}: test "${name}" failed. ${context}`)
})
