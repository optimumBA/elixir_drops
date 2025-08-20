let InfiniteScrollHooks = {}

InfiniteScrollHooks.InfiniteScroll = {
  mounted() {
    this.pending = false
    this.observer = null
    this.isResizing = false
    this.resizeTimeout = null
    this.masonryEl = document.querySelector('[phx-hook="Masonry"]')

    if (this.masonryEl) {
      this.masonryEl._masonryHook = this.masonryEl._masonryHook
    }

    this.setupResizeHandler()

    // Initial positioning and observer setup with retry mechanism
    setTimeout(() => {
      this.positionMarker().then(() => {
        this.connectObserver()
      })
    }, 200)

    this.handleEvent('load-more-complete', () => {
      this.pending = false

      setTimeout(async () => {
        await this.positionMarker()
        this.connectObserver()
      }, 500)
    })
  },

  async positionMarker() {
    if (!this.masonryEl) return

    // Wait for masonry layout to complete before positioning
    if (this.masonryEl._masonryHook?.waitForLayoutComplete) {
      await this.masonryEl._masonryHook.waitForLayoutComplete()
    }

    // Add a small delay to ensure layout is fully settled
    await new Promise((resolve) => setTimeout(resolve, 100))

    // Calculate the height of the masonry container using offsetTop/offsetHeight
    const masonryItems = this.masonryEl.querySelectorAll('.masonry-item')
    if (masonryItems.length === 0) return

    let maxBottom = 0
    masonryItems.forEach((item) => {
      // Use offsetTop + offsetHeight for more stable positioning
      const itemBottom = item.offsetTop + item.offsetHeight
      maxBottom = Math.max(maxBottom, itemBottom)
    })

    // Position the marker 50px below the last masonry item
    this.el.style.position = 'absolute'
    this.el.style.top = `${maxBottom + 50}px`
    this.el.style.left = '0'
    this.el.style.width = '100%'
  },

  setupResizeHandler() {
    this.handleResize = () => {
      this.isResizing = true
      this.disconnectObserver()

      clearTimeout(this.resizeTimeout)
      this.resizeTimeout = setTimeout(async () => {
        await this.positionMarker()
        this.isResizing = false
        if (!this.pending) {
          this.connectObserver()
        }
      }, 800)
    }

    window.addEventListener('resize', this.handleResize)
  },

  updated() {
    if (!this.pending) {
      this.positionMarker().then(() => {
        this.connectObserver()
      })
    }
  },

  destroyed() {
    this.disconnectObserver()
    window.removeEventListener('resize', this.handleResize)
    clearTimeout(this.resizeTimeout)
  },

  connectObserver() {
    if (this.pending || this.isResizing) return

    this.disconnectObserver()

    this.observer = new IntersectionObserver(
      (entries) => {
        const [entry] = entries

        if (entry.isIntersecting && !this.pending && !this.isResizing) {
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
