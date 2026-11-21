'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'link-public-contributor-attributions'
const DIR = `features/steps/${P}__driver`
const cache = {}

function runFile(file, browser) {
  const key = `${file}:${browser}`
  if (cache[key]) return cache[key]
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const args = ['exec', '--', 'mix', 'test', '--trace']
  if (browser) args.push('--include', 'feature')
  args.push(`${DIR}/${file}`)
  const env = { ...process.env, MIX_ARCHIVES: archives }
  if (browser) env.FEATURE_TESTS = 'true'
  const result = spawnSync('mise', args, { cwd: process.cwd(), encoding: 'utf8', timeout: 110000, env })
  const output = `${result.stdout || ''}${result.stderr || ''}`
  const summary = output.match(/(\d+) tests?, (\d+) failures?/)
  const failed = new Set()
  for (const m of output.matchAll(/^\s+\d+\) test (.+?) \(/gm)) failed.add(m[1])
  const ran = new Set()
  for (const m of output.matchAll(/^\s+\* test (.+?) \(\d/gm)) ran.add(m[1])
  cache[key] = { output, summary, failed, ran, status: result.status }
  return cache[key]
}

function assertPasses(file, name, browser) {
  const r = runFile(file, browser)
  const context = `${P}: ran "mix test --trace ${browser ? '--include feature ' : ''}${DIR}/${file}" (exit ${r.status}); output:\n${r.output.slice(-3000)}`
  assert.ok(r.summary, `${P}: no ExUnit summary line found. ${context}`)
  assert.equal(Number(r.summary[1]), 1, `${P}: expected exactly 1 test to run in ${file}. ${context}`)
  assert.ok(r.ran.has(name), `${P}: test "${name}" did not run. ${context}`)
  assert.ok(!r.failed.has(name), `${P}: test "${name}" failed. ${context}`)
  assert.equal(Number(r.summary[2]), 0, `${P}: ${file} reported failures. ${context}`)
}

Then(
  `${P}: each fixture card and Drop detail links its own displayed author and never the visitor or another author, for a guest and for a signed-in third user, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, false)
  }
)

Then(
  `${P}: the avatar and the name of the comment author and of the reply author both link to their own different profiles, not only the top-level comment, not only the name and not the Drop author, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, false)
  }
)

Then(
  `${P}: keyboard, Control-click and middle-click on an author link reach the author profile natively with no nested anchors, no Drop navigation and a visible focus indicator and pointer cursor at 320, 390 and 1280 pixels, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, true)
  }
)

Then(
  `${P}: the resolvable author is linked, the unresolvable author has no profile link, empty link or placeholder link, and no email or account secret is rendered, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, false)
  }
)
