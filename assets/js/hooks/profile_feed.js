let ProfileFeedHooks = {}

// Keeps a profile tab's loaded entries and reading position across tab
// switches and across a visit to a Drop and Back. Both tab containers stay
// mounted (the inactive one is hidden), so their streams keep their entries;
// the hook stores the loaded entry ids and the first visible entry in
// sessionStorage. When a remounted tab renders fewer entries than were saved
// (Back from a Drop, or a fresh page load), it asks the server to restore them
// in one bounded query and then scrolls the saved anchor back into view.
ProfileFeedHooks.ProfileFeed = {
  mounted() {
    this.tab = this.el.dataset.feedTab
    this.key = `profile-feed:${this.el.dataset.profileUserId}:${this.tab}`
    this.restoring = false
    this.restoreDone = false
    this.visible = this.isVisible()
    this.saveQueued = false

    this.onScroll = () => this.queueSave()
    window.addEventListener('scroll', this.onScroll, { passive: true })

    this.handleEvent('profile_feed_restored', ({ tab, anchor }) => {
      if (tab !== this.tab) return
      this.scrollToAnchor(anchor)
    })

    if (this.visible) this.maybeRestore()
  },

  updated() {
    const visible = this.isVisible()
    const becameVisible = visible && !this.visible
    this.visible = visible

    if (visible) {
      this.maybeRestore()
      if (becameVisible && !this.restoring) this.scrollToAnchor(this.saved()?.anchor)
      if (!this.restoring) this.save()
    }
  },

  destroyed() {
    window.removeEventListener('scroll', this.onScroll)
    if (this.visible && !this.restoring) this.save()
  },

  isVisible() {
    return this.el.offsetParent !== null
  },

  entries() {
    return [...this.el.querySelectorAll('[data-feed-entry]')]
  },

  firstVisible() {
    for (const entry of this.entries()) {
      const r = entry.getBoundingClientRect()
      if (r.height > 0 && r.bottom > 0 && r.top < window.innerHeight) return entry.id
    }
    return null
  },

  queueSave() {
    if (!this.visible || this.restoring || this.saveQueued) return
    this.saveQueued = true
    requestAnimationFrame(() => {
      this.saveQueued = false
      if (this.visible && !this.restoring) this.save()
    })
  },

  save() {
    // The bottom of a non-exhausted feed is the load-trigger zone, not a
    // reading position: scrolls that request a batch (and the re-render after
    // it appends) land there and must not overwrite the parked anchor.
    const nearBottom = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 400
    const exhausted = this.el.querySelector('[data-end-of-timeline="true"]')
    if (nearBottom && !exhausted) return
    const ids = this.entries().map((entry) => entry.id)
    if (ids.length === 0) return
    sessionStorage.setItem(this.key, JSON.stringify({ ids, anchor: this.firstVisible() }))
  },

  saved() {
    try {
      return JSON.parse(sessionStorage.getItem(this.key))
    } catch {
      return null
    }
  },

  maybeRestore() {
    if (this.restoring || this.restoreDone) return

    const saved = this.saved()
    if (!saved || !Array.isArray(saved.ids) || saved.ids.length === 0) {
      this.restoreDone = true
      return
    }

    const rendered = this.entries().map((entry) => entry.id)
    if (saved.ids.some((id) => !rendered.includes(id))) {
      // On a dead render the socket is not connected yet; updated/1 retries
      // after the live join has rendered the first batch.
      if (!this.liveSocket.isConnected()) return
      this.restoring = true
      this.pushEvent('restore_profile_feed', {
        tab: this.tab,
        ids: saved.ids,
        anchor: saved.anchor,
      })
    } else {
      this.scrollToAnchor(saved.anchor)
    }
  },

  // Scrolls the anchor to the top of the viewport, retrying while the feed
  // settles (Masonry lays out cards asynchronously), then records the
  // restored state.
  scrollToAnchor(anchor) {
    const el = anchor && document.getElementById(anchor)
    if (!el) {
      this.restoring = false
      this.restoreDone = true
      return
    }

    this.restoring = true
    this.restoreDone = true
    let tries = 0

    const attempt = () => {
      el.scrollIntoView({ block: 'start' })
      tries++
      if (Math.abs(el.getBoundingClientRect().top) > 2 && tries < 20) {
        setTimeout(attempt, 100)
      } else {
        this.restoring = false
        this.save()
      }
    }

    requestAnimationFrame(attempt)
  },
}

export default ProfileFeedHooks