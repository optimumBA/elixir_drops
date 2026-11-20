'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'public-profile-page-and-drops-tab'
const DIR = `features/steps/${P}__driver`
const cache = {}

function runFile(file) {
  if (cache[file]) return cache[file]
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const result = spawnSync('mise', ['exec', '--', 'mix', 'test', '--trace', `${DIR}/${file}`], {
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
  cache[file] = { output, summary, failed, ran, status: result.status }
  return cache[file]
}

function assertPasses(file, name) {
  const r = runFile(file)
  const context = `${P}: ran "mix test --trace ${DIR}/${file}" (exit ${r.status}); output:\n${r.output.slice(-3000)}`
  assert.ok(r.summary, `${P}: no ExUnit summary line found. ${context}`)
  assert.equal(Number(r.summary[1]), 1, `${P}: expected exactly 1 test to run in ${file}. ${context}`)
  assert.ok(r.ran.has(name), `${P}: test "${name}" did not run. ${context}`)
  assert.ok(!r.failed.has(name), `${P}: test "${name}" failed. ${context}`)
  assert.equal(Number(r.summary[2]), 0, `${P}: ${file} reported failures. ${context}`)
}

Then(`${P}: the test file {string} runs its test {string} and it passes`, function (file, name) {
  assertPasses(file, name)
})

Then(
  `${P}: the profile pages of every viewer in {string} test {string} show no draft, email, token, search history or bookmark text`,
  function (file, name) {
    assertPasses(file, name)
  }
)
