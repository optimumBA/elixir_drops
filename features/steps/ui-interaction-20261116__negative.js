'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { Then } = require('@cucumber/cucumber')

const normalize = (text) => text.replace(/\s+/g, ' ').trim()

Then('ui-interaction-20261116: {string} does not contain the text {string}', function (file, text) {
  const full = path.join(this.root, file)
  assert.ok(fs.existsSync(full), `ui-interaction-20261116: ${file} does not exist under ${this.root}`)
  const source = normalize(fs.readFileSync(full, 'utf8'))
  assert.ok(!source.includes(normalize(text)), `ui-interaction-20261116: ${file} must not contain: ${text}`)
})
