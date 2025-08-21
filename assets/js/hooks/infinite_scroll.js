let InfiniteScrollHooks = {}

InfiniteScrollHooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.observer = null
    this.isResizing = false
    this.masonryEl = document.querySelector('[phx-hook="Masonry"]')

    document.addEventListener('masonry-layout-complete', () => {
      this.repositionAndReconnect()
    })

    this.handleEvent('load-more-complete', () => {
      this.pending = false

      setTimeout(() => {
        this.connectObserver()
      }, 500)
    })

    this.handleResize = () => {
      this.isResizing = true
      this.disconnectObserver()
    }

    window.addEventListener('resize', this.handleResize)
  },

  repositionAndReconnect() {
    this.isResizing = false
    this.repositionMarker()
    this.connectObserver()
  },

  repositionMarker() {
    if (!this.masonryEl) return

    const masonryGrid = this.masonryEl

    masonryGrid.after(this.el)
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
  
    this.pushEvent('load-more', { layout_complete: true })
  },
}

export default InfiniteScrollHooks
