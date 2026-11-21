'use strict'

// Usage: node new_tab.cjs <base-url> <profile-path> <github-url>
// Opens the profile in Chromium, answers every github.com request from a local
// static fixture, aborts any other non-local request, activates the
// View on GitHub link and prints one JSON line describing the outcome.
const path = require('node:path')
const { chromium } = require(path.resolve('assets/node_modules/playwright'))

const [base, profilePath, githubUrl] = process.argv.slice(2)
const FIXTURE = '<!doctype html><title>GitHub fixture</title><p id="fixture">GitHub fixture page</p>'

const isLocal = (host) => host === '127.0.0.1' || host === 'localhost'
const isGithub = (host) => host === 'github.com' || host.endsWith('.github.com')

;(async () => {
  const browser = await chromium.launch({ headless: true })
  try {
    const context = await browser.newContext()
    const githubRequests = []
    const outsideRequests = []
    await context.route(
      (url) => !isLocal(url.hostname) && url.protocol !== 'data:' && url.protocol !== 'blob:',
      (route) => {
        const url = new URL(route.request().url())
        if (url.hostname === 'github.com') {
          githubRequests.push(url.href)
          return route.fulfill({ status: 200, contentType: 'text/html', body: FIXTURE })
        }
        if (!isGithub(url.hostname)) outsideRequests.push(url.href)
        return route.abort()
      }
    )

    const page = await context.newPage()
    await page.goto(base + profilePath)
    await page.waitForSelector('#public-profile')
    // The profile header text, or null when the original tab no longer shows the profile.
    const text = () =>
      page.evaluate(() => {
        const el = document.getElementById('public-profile')
        return el ? el.innerText : null
      })
    const textBefore = await text()
    const pagesBefore = context.pages().length

    const opened = context.waitForEvent('page', { timeout: 10000 }).catch(() => null)
    await page.getByRole('link', { name: 'View on GitHub', exact: true }).click()
    const popup = await opened
    let popupUrl = null
    if (popup) {
      await popup.waitForLoadState('load').catch(() => {})
      popupUrl = popup.url()
    }
    await page.waitForTimeout(500)

    console.log(
      JSON.stringify({
        pagesBefore,
        pagesAfter: context.pages().length,
        popupUrl,
        originalUrl: page.url(),
        textBefore,
        textAfter: await text(),
        githubRequests,
        outsideRequests,
        expectedGithubUrl: githubUrl
      })
    )
  } finally {
    await browser.close()
  }
})().catch((error) => {
  console.error(String(error && error.stack ? error.stack : error))
  process.exit(1)
})
