let InfiniteScrollHooks = {}

InfiniteScrollHooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.observer = null
    this._scrollListener = null
    this.masonryEl = document.querySelector('[phx-hook="Masonry"]')

    if (this.masonryEl) {
      this.masonryEl._masonryHook = this.masonryEl.__liveViewHooks__?.Masonry
    }

    // Expose hook reference on the element for introspection (e.g. test support).
    this.el._infiniteScrollHook = this

    this.connectObserver()

    // Check immediately: if not scrollable yet, load more to fill the page.
    // A 200ms delay lets Masonry finish layout before we measure scrollHeight.
    setTimeout(() => this.checkAndLoad(), 200)

    this.handleEvent('load_more_complete', () => {
      this.pending = false

      setTimeout(() => {
        this.connectObserver()
        // After loading more, re-check immediately in case still near bottom.
        this.checkAndLoad()
      }, 500)
    })
  },

  updated() {
    if (!this.pending) {
      this.connectObserver()
    }
  },

  destroyed() {
    this.disconnectObserver()
  },

  connectObserver() {
    if (this.pending) return

    this.disconnectObserver()

    this.observer = new IntersectionObserver(
      (entries) => {
        const [entry] = entries

        if (entry.isIntersecting && !this.pending) {
          this.loadMore()
        }
      },
      {
        rootMargin: '300px',
        threshold: 0,
      }
    )

    this.observer.observe(this.el)

    // Scroll-event fallback: fires loadMore when near document bottom.
    // Covers the case where IntersectionObserver is already in "intersecting"
    // state (transition-based: does not re-fire on repeated scrolls into an
    // already-visible zone).
    this._scrollListener = () => {
      if (this.pending) return
      const scrollBottom = window.scrollY + window.innerHeight
      const docHeight = document.documentElement.scrollHeight
      // Trigger when within 400px of page bottom (larger than rootMargin so
      // it definitely fires before the observer would on a normal layout).
      if (scrollBottom >= docHeight - 400) {
        this.loadMore()
      }
    }
    window.addEventListener('scroll', this._scrollListener, { passive: true })
  },

  disconnectObserver() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
    if (this._scrollListener) {
      window.removeEventListener('scroll', this._scrollListener)
      this._scrollListener = null
    }
  },

  // Check whether we should load more right now. Called on mount and after
  // each load cycle. Handles two cases:
  //   1. Page is not scrollable (all content fits in viewport) — load to fill.
  //   2. Marker is already visible in viewport or near-viewport zone — load now.
  checkAndLoad() {
    if (this.pending) return
    if (this.el.dataset.endOfTimeline === 'true') return

    const scrollHeight = document.documentElement.scrollHeight
    const innerHeight = window.innerHeight

    // Case 1: page content doesn't overflow the viewport.
    if (scrollHeight <= innerHeight + 100) {
      this.loadMore()
      return
    }

    // Case 2: marker is within 300px of the viewport bottom right now.
    const rect = this.el.getBoundingClientRect()
    if (rect.top <= innerHeight + 300) {
      this.loadMore()
    }
  },

  async loadMore() {
    if (this.pending) return

    if (this.el.dataset.endOfTimeline === 'true') return

    this.pending = true
    this.disconnectObserver()

    if (this.masonryEl && this.masonryEl._masonryHook?.waitForLayoutComplete) {
      await this.masonryEl._masonryHook.waitForLayoutComplete()
    }

    this.pushEvent('load_more', { layout_complete: true })
  },
}

InfiniteScrollHooks.InfiniteScrollNotifications = {
  mounted() {
    this.observer = null

    this.connectObserver()

    this.handleEvent('load_more_notifications_complete', () => {
      setTimeout(() => {
        this.connectObserver()
      }, 500)
    })
  },

  destroyed() {
    this.disconnectObserver()
  },

  connectObserver() {
    this.observer = new IntersectionObserver(
      (entries) => {
        const [entry] = entries

        if (entry.isIntersecting) {
          this.loadMore()
        }
      },
      {
        rootMargin: '150px',
        threshold: 0.1,
      }
    )

    this.observer.observe(this.el)
  },

  disconnectObserver() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  },

  async loadMore() {
    this.disconnectObserver()

    this.pushEvent('load_more_notifications')
  },
}

export default InfiniteScrollHooks
