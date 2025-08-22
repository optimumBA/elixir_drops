let InfiniteScrollHooks = {}

InfiniteScrollHooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.observer = null
    this.masonryEl = document.querySelector('[phx-hook="Masonry"]')

    if (this.masonryEl) {
      this.masonryEl._masonryHook = this.masonryEl.__liveViewHooks__?.Masonry
    }

    this.connectObserver()

    this.handleEvent('load-more-complete', () => {
      this.pending = false

      setTimeout(() => {
        this.connectObserver()
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
    if (this.pending) return

    if (this.el.dataset.endOfTimeline === 'true') return

    this.pending = true
    this.disconnectObserver()

    if (this.masonryEl && this.masonryEl._masonryHook?.waitForLayoutComplete) {
      await this.masonryEl._masonryHook.waitForLayoutComplete()
    }

    this.pushEvent('load-more', { layout_complete: true })
  },
}

export default InfiniteScrollHooks
