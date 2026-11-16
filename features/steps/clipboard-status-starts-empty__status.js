'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { Given, When, Then } = require('@cucumber/cucumber')

const P = 'clipboard-status-starts-empty'
const COMPONENT = 'lib/elixir_drops_web/live/drop_components.ex'
const HOOK = 'assets/js/hooks/copy_to_clipboard.js'
const normalize = (text) => text.replace(/\s+/g, ' ').trim()

function read(world, file) {
  const full = path.join(world.root || process.cwd(), file)
  assert.ok(fs.existsSync(full), `${P}: ${file} does not exist under ${world.root}`)
  return fs.readFileSync(full, 'utf8')
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
  constructor(classes = [], textContent = '') {
    this.classList = new FakeClassList(classes)
    this.textContent = textContent
    this.listeners = {}
  }
  addEventListener(type, fn) {
    ;(this.listeners[type] = this.listeners[type] || []).push(fn)
  }
  click() {
    const event = { preventDefault() {}, stopPropagation() {}, target: this }
    ;(this.listeners.click || []).forEach((fn) => fn(event))
  }
}

class FakeClipboardJS {
  constructor(element) {
    this.element = element
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

// The status element as rendered by the real component source: opening tag and the text span.
function statusMarkup(world) {
  const source = read(world, COMPONENT)
  const start = source.indexOf('def copied_link_popup_message(')
  assert.ok(start >= 0, `${P}: ${COMPONENT} must define copied_link_popup_message/1`)
  const body = source.slice(start, source.indexOf('\n  end\n', start))
  const open = /<p\b[^<]*?id="copy-confirm-message"[^<]*?>/.exec(body)
  assert.ok(open, `${P}: copied_link_popup_message/1 must render <p id="copy-confirm-message">`)
  const span = /<span\b[^>]*id="copy-confirm-text"[^>]*>([\s\S]*?)<\/span>/.exec(body)
  assert.ok(span, `${P}: copied_link_popup_message/1 must render <span id="copy-confirm-text">`)
  const classes = []
  const classAttr = /class=(?:\{\[([\s\S]*?)\]\}|"([^"]*)")/.exec(open[0])
  if (classAttr) {
    const region = classAttr[1] || classAttr[2] || ''
    const strings = classAttr[1] ? region.match(/"([^"]*)"/g) || [] : [region]
    strings.forEach((s) => s.replace(/"/g, '').split(/\s+/).filter(Boolean).forEach((c) => classes.push(c)))
  }
  return { open: open[0], text: normalize(span[1]), classes }
}

const hasToken = (tag, name) => new RegExp(`(?<![\\w-])${name}(?![\\w-])`).test(tag)

Given(`${P}: the copy status markup and link-copy hook are loaded with a fake clipboard library`, function () {
  this.root = process.cwd()
  this.markup = statusMarkup(this)
  let code = read(this, HOOK)
  code = code.replace(/import\s+ClipboardJS\s+from\s+['"]clipboard['"]/, 'const ClipboardJS = __ClipboardJS')
  code = code.replace(/export\s+default\s+/, 'module.exports = ')

  FakeClipboardJS.instances = []
  this.timers = []
  this.link = new FakeElement()
  this.confirmText = new FakeElement([], this.markup.text)
  this.confirm = new FakeElement(this.markup.classes)
  const elements = { '#copy-confirm-message': this.confirm, '#copy-confirm-text': this.confirmText }
  const sandbox = {
    module: { exports: {} },
    __ClipboardJS: FakeClipboardJS,
    document: { querySelector: (selector) => elements[selector.replace(/`/g, '')] || null },
    setTimeout: (fn, ms) => this.timers.push({ fn, ms }),
    clearTimeout: () => {},
    console,
  }
  vm.runInNewContext(code, sandbox, { filename: HOOK })
  const hooks = sandbox.module.exports
  assert.ok(hooks && hooks.CopyToClipboard, `${P}: ${HOOK} must export CopyToClipboard hook`)
  hooks.CopyToClipboard.mounted.call({ el: this.link })
  assert.ok(FakeClipboardJS.instances.length >= 1, `${P}: the hook must create a ClipboardJS instance`)
})

When(`${P}: the visitor clicks the copy button`, function () {
  this.link.click()
})

When(`${P}: the clipboard library reports {word}`, function (outcome) {
  assert.ok(['success', 'error'].includes(outcome), `${P}: unknown outcome ${outcome}`)
  FakeClipboardJS.instances.forEach((instance) => instance.emit(outcome))
})

When(`${P}: the confirmation timers elapse`, function () {
  this.timers.splice(0).forEach((timer) => timer.fn())
})

Then(`${P}: the status is a polite live region that is not hidden from assistive technology`, function () {
  const tag = this.markup.open
  assert.ok(/role="status"/.test(tag), `${P}: status element needs role="status": ${tag}`)
  assert.ok(/aria-live="polite"/.test(tag), `${P}: status element needs aria-live="polite": ${tag}`)
  assert.ok(!/aria-hidden/.test(tag), `${P}: status element must not use aria-hidden: ${tag}`)
  assert.ok(!hasToken(tag, 'hidden'), `${P}: status element must not use the display:none class hidden: ${tag}`)
})

Then(`${P}: the status text is empty`, function () {
  assert.equal(this.confirmText.textContent.trim(), '', `${P}: status text must be empty but is "${this.confirmText.textContent}"`)
})

Then(`${P}: the status text makes no success or failure claim`, function () {
  const text = this.confirmText.textContent
  assert.ok(!/cop(y|ied)|fail|success|error/i.test(text), `${P}: status text claims a result: "${text}"`)
})

Then(`${P}: the status is visually hidden`, function () {
  assert.ok(this.confirm.classList.contains('sr-only'), `${P}: status must carry sr-only while idle; text is "${this.confirmText.textContent}"`)
})

Then(`${P}: the status is visually shown`, function () {
  assert.ok(!this.confirm.classList.contains('sr-only'), `${P}: status still carries sr-only`)
  assert.ok(!this.confirm.classList.contains('hidden'), `${P}: status still carries hidden`)
})

Then(`${P}: the status text is {string}`, function (text) {
  assert.equal(this.confirmText.textContent.trim(), text)
})

Then(`${P}: the status text does not contain {string}`, function (text) {
  assert.ok(!this.confirmText.textContent.includes(text), `${P}: status text must not contain "${text}" but is "${this.confirmText.textContent}"`)
})

Then(`${P}: {string} matches the pattern {string}`, function (file, pattern) {
  const source = normalize(read(this, file))
  assert.ok(new RegExp(pattern).test(source), `${P}: ${file} (whitespace-normalized) must match /${pattern}/`)
})

Then(`${P}: {string} contains the text {string}`, function (file, text) {
  assert.ok(normalize(read(this, file)).includes(normalize(text)), `${P}: ${file} must contain: ${text}`)
})
