'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { Given, Then } = require('@cucumber/cucumber')

const normalize = (text) => text.replace(/\s+/g, ' ').trim()

function readSource(world, file) {
  const full = path.join(world.root, file)
  assert.ok(fs.existsSync(full), `ui-visual-20261116: ${file} does not exist under ${world.root}`)
  return normalize(fs.readFileSync(full, 'utf8'))
}

Given('ui-visual-20261116: the ElixirDrops source checkout', function () {
  this.root = process.cwd()
  assert.ok(
    fs.existsSync(path.join(this.root, 'lib', 'elixir_drops_web')),
    `ui-visual-20261116: lib/elixir_drops_web not found under ${this.root}`
  )
})

Then('ui-visual-20261116: {string} exists', function (file) {
  const full = path.join(this.root, file)
  assert.ok(fs.existsSync(full), `ui-visual-20261116: ${file} must exist under ${this.root}`)
})

Then('ui-visual-20261116: {string} matches the pattern {string}', function (file, pattern) {
  const source = readSource(this, file)
  assert.ok(
    new RegExp(pattern).test(source),
    `ui-visual-20261116: ${file} (whitespace-normalized) must match /${pattern}/`
  )
})

Then('ui-visual-20261116: {string} does not match the pattern {string}', function (file, pattern) {
  const source = readSource(this, file)
  const found = new RegExp(pattern).exec(source)
  assert.ok(
    !found,
    `ui-visual-20261116: ${file} (whitespace-normalized) must not match /${pattern}/ but contains: ${found && found[0].slice(0, 200)}`
  )
})

Then('ui-visual-20261116: {string} contains the text {string}', function (file, text) {
  const source = readSource(this, file)
  assert.ok(source.includes(normalize(text)), `ui-visual-20261116: ${file} must contain: ${text}`)
})

Then('ui-visual-20261116: {string} does not contain the text {string}', function (file, text) {
  const source = readSource(this, file)
  assert.ok(!source.includes(normalize(text)), `ui-visual-20261116: ${file} must not contain: ${text}`)
})
