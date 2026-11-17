'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { Then } = require('@cucumber/cucumber')

const P = 'unsupported-oauth-providers-return-not-found'
const FILE = `features/steps/${P}__driver/unsupported_providers_test.exs`
const EXISTING = 'test/elixir_drops_web/controllers/github_auth_controller_test.exs'
const EXISTING_MODULE = 'ElixirDropsWeb.GithubAuthControllerTest'
const MIN_EXISTING = 9
let cached = null

function run() {
  if (cached) return cached
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const result = spawnSync('mise', ['exec', '--', 'mix', 'test', '--trace', FILE, EXISTING], {
    cwd: process.cwd(),
    encoding: 'utf8',
    timeout: 110000,
    env: { ...process.env, MIX_ARCHIVES: archives },
  })
  const output = `${result.stdout || ''}${result.stderr || ''}`
  const failed = []
  for (const m of output.matchAll(/^\s+\d+\) test (.+) \(([\w.]+)\)$/gm)) failed.push({ name: m[1], module: m[2] })
  const ran = []
  for (const m of output.matchAll(/\* test ([^*]+?) \(\d[\d.]*ms\)/g)) ran.push(m[1])
  cached = { output, failed, ran, status: result.status }
  return cached
}

function context(r) {
  return `${P}: ran "mix test --trace ${FILE} ${EXISTING}" (exit ${r.status}); output:\n${r.output.slice(-3000)}`
}

Then(`${P}: the isolated regression {string} passes`, function (name) {
  const r = run()
  assert.ok(r.ran.includes(name), `${P}: test "${name}" did not run. ${context(r)}`)
  assert.ok(!r.failed.some((f) => f.name === name), `${P}: test "${name}" failed. ${context(r)}`)
})

Then(`${P}: the existing GitHub auth controller tests pass`, function () {
  const r = run()
  const existing = r.ran.filter((n) => n.startsWith('GET /auth/'))
  assert.ok(existing.length >= MIN_EXISTING, `${P}: expected at least ${MIN_EXISTING} existing "GET /auth/" tests to run in ${EXISTING}, saw ${existing.length}. ${context(r)}`)
  const bad = r.failed.filter((f) => f.module === EXISTING_MODULE)
  assert.equal(bad.length, 0, `${P}: failing tests in ${EXISTING_MODULE}: ${bad.map((f) => f.name).join('; ')}. ${context(r)}`)
})
