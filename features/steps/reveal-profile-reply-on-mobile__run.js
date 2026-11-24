'use strict'

const assert = require('node:assert/strict')
const { spawnSync } = require('node:child_process')
const { performance } = require('node:perf_hooks')

const P = 'reveal-profile-reply-on-mobile'
const FILE = `features/steps/${P}__driver/discussion_test.exs`
const VIEWPORTS = [[390, 844], [1280, 800]]
const REPLY = 'RPL-0001 old reply'
const COMMENT = 'CMT-0002 old top-level comment'
const TESTS = {
  discussion_journey: 'reveal the selected older public discussion entries',
  discussion_observer_good: 'qualify the observer on connected navigation',
  discussion_observer_bad: 'qualify the observer on the baseline full-document navigation'
}

function run(tag) {
  const archives = process.env.MIX_ARCHIVES || `${process.env.MIX_HOME || `${process.env.HOME}/.mix`}/archives-otp27`
  const args = ['exec', '--', 'mix', 'test', '--trace', '--only', tag, FILE]
  const env = { ...process.env, MIX_ARCHIVES: archives, MIX_ENV: 'test', FEATURE_TESTS: 'true' }
  const start = performance.now()
  const result = spawnSync('mise', args, { encoding: 'utf8', timeout: 105_000, env })
  const elapsed = ((performance.now() - start) / 1000).toFixed(1)
  const output = `${result.stdout || ''}\n${result.stderr || ''}`
  const context = `Test "${TESTS[tag]}": mise ${args.join(' ')} (exit ${result.status}, ${elapsed}s).`
  return { result, output, context }
}

function evidence(report, expected, status) {
  const { result, output, context } = report
  assert.ifError(result.error)
  assert.equal(result.status, status, `${context}\n${output}`)
  const summary = status === 0 ? '3 tests, 0 failures, 2 excluded' : '3 tests, 1 failure, 2 excluded'
  assert.ok(output.includes(summary), `${context}\nExpected one selected test to run: ${summary}.\n${output}`)
  const records = [...output.matchAll(/DISCUSSION_EVIDENCE (\[[^\r\n]+\])$/gm)]
  assert.equal(records.length, 1, `${context}\nExpected one completed browser evidence record.\n${output}`)
  const rows = JSON.parse(records[0][1])
  assert.deepEqual(rows.map(row => [row.width, row.height, row.mode, row.text]), expected, context)
  assert.ok(rows.every(row => row.matches === 1 && row.nested && row.back.endsWith('/comments')), context)
  return rows
}

function expectedRows(viewports, modes, reply, comment) {
  return viewports.flatMap(([width, height]) => modes.flatMap(mode =>
    (mode === 'connected' ? [reply, comment] : [reply]).map(text => [width, height, mode, text])))
}

if (require.main === module) {
  // Shape-only focused observer controls: each selects one test using exactly
  // the same real-browser journey, fixture, and assertions as acceptance.
  try {
    const mode = process.argv[2]
    assert.ok(['good', 'bad'].includes(mode))
    const good = mode === 'good'
    const report = run(`discussion_observer_${mode}`)
    const rows = evidence(report, expectedRows(VIEWPORTS, [good ? 'connected' : 'full-document'], REPLY, COMMENT), good ? 0 : 2)
    if (good) {
      assert.ok(rows.every(row => row.visible && row.inViewport), report.context)
      console.log('observer accepted the visible connected bodies at both viewports')
    } else {
      assert.ok(report.output.includes('selected discussion body not visible in viewport:'), report.context)
      assert.ok(rows.every(row => !row.visible && !row.inViewport && row.parentDisplay === 'none'), report.context)
      console.log('observer rejected the hidden full-document reply at both viewports')
      process.exitCode = 1
    }
  } catch (error) {
    console.error(error.message)
    process.exitCode = 3
  }
} else {
  const { Then } = require('@cucumber/cucumber')

  Then(`${P}: at {int} by {int} and {int} by {int} the connected discussion links reveal {string} and {string}, and full-document navigation to the selected reply href reveals {string}, with Back to Comments each time`,
    { timeout: 115_000 }, async function (w1, h1, w2, h2, reply, comment, deepReply) {
      assert.equal(deepReply, reply, 'Both navigation modes must target the same reply')
      const report = run('discussion_journey')
      await this.attach(`${report.context}\n${report.output}`, 'text/plain')
      const rows = evidence(report, expectedRows([[w1, h1], [w2, h2]], ['connected', 'full-document'], reply, comment), 0)
      assert.ok(rows.every(row => row.visible && row.inViewport), report.context)
    })
}
