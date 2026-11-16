'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { Given, When, Then } = require('@cucumber/cucumber')

const normalize = (text) => text.replace(/\s+/g, ' ').trim()

function readSource(world, file) {
  const full = path.join(world.root, file)
  assert.ok(fs.existsSync(full), `ui-copy-20261116: ${file} does not exist under ${world.root}`)
  return normalize(fs.readFileSync(full, 'utf8'))
}

class FakeClassList {
  constructor(initial) {
    this.set = new Set(initial)
  }
  add(name) {
    this.set.add(name)
  }
  remove(name) {
    this.set.delete(name)
  }
  contains(name) {
    return this.set.has(name)
  }
}

class FakeElement {
  constructor(initialClasses = [], textContent = '') {
    this.classList = new FakeClassList(initialClasses)
    this.textContent = textContent
    this.listeners = {}
    this.children = {}
  }
  addEventListener(type, fn) {
    ;(this.listeners[type] = this.listeners[type] || []).push(fn)
  }
  querySelector(selector) {
    return this.children[selector] || null
  }
  click() {
    const event = { preventDefault() {}, stopPropagation() {}, target: this }
    ;(this.listeners.click || []).forEach((fn) => fn(event))
  }
}

class FakeClipboardJS {
  constructor(element, options) {
    this.element = element
    this.options = options
    this.handlers = {}
    FakeClipboardJS.instances.push(this)
  }
  on(type, fn) {
    ;(this.handlers[type] = this.handlers[type] || []).push(fn)
    return this
  }
  emit(type) {
    const event = { action: 'copy', text: 'text', trigger: this.element, clearSelection() {} }
    ;(this.handlers[type] || []).forEach((fn) => fn(event))
  }
}

Given('ui-copy-20261116: the ElixirDrops source checkout', function () {
  this.root = process.cwd()
  assert.ok(
    fs.existsSync(path.join(this.root, 'lib', 'elixir_drops_web')),
    `ui-copy-20261116: lib/elixir_drops_web not found under ${this.root}`
  )
})

Then('ui-copy-20261116: {string} contains the text {string}', function (file, text) {
  const source = readSource(this, file)
  assert.ok(source.includes(normalize(text)), `ui-copy-20261116: ${file} must contain: ${text}`)
})

Then('ui-copy-20261116: {string} does not contain the text {string}', function (file, text) {
  const source = readSource(this, file)
  assert.ok(!source.includes(normalize(text)), `ui-copy-20261116: ${file} must not contain: ${text}`)
})

Given('ui-copy-20261116: the link-copy hook is mounted with a fake clipboard library', function () {
  this.root = process.cwd()
  const file = 'assets/js/hooks/copy_to_clipboard.js'
  let code = fs.readFileSync(path.join(this.root, file), 'utf8')
  code = code.replace(/import\s+ClipboardJS\s+from\s+['"]clipboard['"]/, 'const ClipboardJS = __ClipboardJS')
  code = code.replace(/export\s+default\s+/, 'module.exports = ')

  FakeClipboardJS.instances = []
  this.timers = []
  this.link = new FakeElement()
  this.confirm = new FakeElement(['hidden'])
  this.confirmText = new FakeElement([], 'initial')
  this.confirm.children['#copy-confirm-text'] = this.confirmText

  const elements = {
    '#copy-confirm-message': this.confirm,
    '#copy-confirm-text': this.confirmText,
  }
  const sandbox = {
    module: { exports: {} },
    __ClipboardJS: FakeClipboardJS,
    document: { querySelector: (selector) => elements[selector.replace(/`/g, '')] || null },
    setTimeout: (fn, ms) => this.timers.push({ fn, ms }),
    clearTimeout: () => {},
    console,
  }
  vm.runInNewContext(code, sandbox, { filename: file })
  const hooks = sandbox.module.exports
  assert.ok(hooks && hooks.CopyToClipboard, `ui-copy-20261116: ${file} must export CopyToClipboard hook`)
  hooks.CopyToClipboard.mounted.call({ el: this.link })
  assert.ok(FakeClipboardJS.instances.length >= 1, 'ui-copy-20261116: the hook must create a ClipboardJS instance')
})

When('ui-copy-20261116: the visitor clicks the copy link', function () {
  this.link.click()
})

When('ui-copy-20261116: the clipboard library reports {word}', function (outcome) {
  assert.ok(['success', 'error'].includes(outcome), `ui-copy-20261116: unknown outcome ${outcome}`)
  FakeClipboardJS.instances.forEach((instance) => instance.emit(outcome))
})

When('ui-copy-20261116: the confirmation timers elapse', function () {
  const timers = this.timers.splice(0)
  timers.forEach((timer) => timer.fn())
})

Then('ui-copy-20261116: the copy message is hidden', function () {
  assert.ok(
    this.confirm.classList.contains('hidden'),
    `ui-copy-20261116: copy message must be hidden but shows "${this.confirmText.textContent}"`
  )
})

Then('ui-copy-20261116: the copy message is visible with the text {string}', function (text) {
  assert.ok(!this.confirm.classList.contains('hidden'), 'ui-copy-20261116: copy message is still hidden')
  assert.equal(this.confirmText.textContent.trim(), text)
})
