'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'profile-github-opens-new-tab'
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
  `${P}: the single View on GitHub anchor of the viewed contributor has target _blank, rel with noopener and noreferrer, the contributor's own GitHub URL, the same label and no script handler, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, false)
  }
)

Then(
  `${P}: activating View on GitHub opens exactly one new browsing context at the contributor's GitHub URL while the original profile page keeps its URL and content, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, true)
  }
)

Then(
  `${P}: every non-GitHub link on the profile keeps its href and has no target, for a guest and a signed-in user, in file {string} test {string}`,
  function (file, name) {
    assertPasses(file, name, false)
  }
)
