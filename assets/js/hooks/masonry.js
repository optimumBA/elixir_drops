import Masonry from 'masonry-layout'
import imagesLoaded from 'imagesloaded'

let MasonryHooks = {}

MasonryHooks.Masonry = {
  mounted() {
    this.handleResize = this.debounce(() => {
      this.sendViewportDimensions()
      if (this.masonry) {
        this.masonry.layout()
      }
    }, 300)

    window.addEventListener('resize', this.handleResize)

    this.el.addEventListener('load_masonry', () => {
      // Cancel mounted timer if still pending
      if (this._mountedTimer) {
        cancelAnimationFrame(this._mountedTimer)
        this._mountedTimer = null
      }

      // Reset state (triggered by phx-connected or search reset)
      if (this.masonry) {
        this.masonry.destroy()
        this.masonry = null
      }
      this.isLayouting = false
      this.layoutCompleteCallbacks = []
      this.trackedItems = new Set()

      this.sendViewportDimensions()

      this._mountedTimer = requestAnimationFrame(() => {
        this._mountedTimer = null
        this.initializeMasonry()
      })
    })

    // Initialize immediately on mount (dead render already has drops in DOM)
    // so cards get positioned without waiting for WS connect
    this.isLayouting = false
    this.layoutCompleteCallbacks = []
    this.trackedItems = new Set()

    this._mountedTimer = requestAnimationFrame(() => {
      this._mountedTimer = null
      this.initializeMasonry()
    })
  },

  updated() {
    if (this.masonry) {
      const items = this.el.querySelectorAll('.masonry-item')

      if (items.length > 0) {
        const newItems = []
        items.forEach((item) => {
          if (!this.trackedItems.has(item.id)) {
            newItems.push(item)
            this.trackedItems.add(item.id)
          }
        })

        if (newItems.length > 0) {
          // Synchronously hide new items before any defer so they are never
          // painted in static document flow (unpositioned).
          newItems.forEach((item) => {
            item.classList.add('masonry-item-pending')
          })

          // rAF instead of setTimeout(150): appended()+layout() run before
          // the next browser paint, eliminating the visible-but-unpositioned window.
          requestAnimationFrame(() => {
            this.appendNewItems(newItems)
          })
        }
      }
    } else if (!this._mountedTimer) {
      requestAnimationFrame(() => {
        this.initializeMasonry()
      })
    }
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize)
    if (this.masonry) {
      this.masonry.destroy()
    }
  },

  initializeMasonry() {
    // If eager pre-connect init ran, destroy it first to take clean ownership
    if (this.el._eagerMasonry) {
      this.el._eagerMasonry.destroy()
      this.el._eagerMasonry = null
    }

    if (this.masonry) {
      this.masonry.destroy()
      this.masonry = null
    }

    this.el.classList.add('masonry-js-init')
    this.el.classList.remove('masonry-ready')

    if (!this.el.querySelector('.grid-sizer')) {
      const gridSizer = document.createElement('div')
      gridSizer.className = 'grid-sizer'
      this.el.prepend(gridSizer)
    }

    // Strip any items that were hidden mid-flight (e.g. load_masonry fired while
    // appendNewItems was waiting on imagesLoaded). Without this, those items
    // would stay opacity:0;visibility:hidden after re-init since initializeMasonry
    // does not call appendNewItems for already-tracked nodes.
    this.el.querySelectorAll('.masonry-item-pending').forEach((item) => {
      item.classList.remove('masonry-item-pending')
    })

    this.masonry = new Masonry(this.el, {
      itemSelector: '.masonry-item',
      columnWidth: '.grid-sizer',
      gutter: 24,
      percentPosition: false,
      transitionDuration: '0.0s',
      stagger: 0,
    })

    this.masonry.on('layoutComplete', () => {
      this.isLayouting = false

      if (!this.el.classList.contains('masonry-ready')) {
        // Double rAF: ensures browser commits positioned paint before opacity transition
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            this.el.classList.add('masonry-ready')
          })
        })
      }

      while (this.layoutCompleteCallbacks.length > 0) {
        const callback = this.layoutCompleteCallbacks.shift()
        callback()
      }
    })

    const items = this.el.querySelectorAll('.masonry-item')
    items.forEach((item) => {
      this.trackedItems.add(item.id)
    })

    // Skip fade-in for cards already in DOM (SPA back-navigation)
    const existingCards = this.el.querySelectorAll('.drop-card')
    existingCards.forEach((card) => {
      card.classList.add('animation-complete')
    })

    this.layoutWithImageLoading()
  },

  appendNewItems(newItems) {
    this.isLayouting = true

    if (this.masonry && newItems.length > 0) {
      this.masonry.appended(newItems)

      // Safety timeout: if imagesLoaded never fires (e.g. external avatar URL hangs),
      // unblock isLayouting after 3 seconds so the next scroll can trigger load_more.
      const appendSafetyTimer = setTimeout(() => {
        if (this.isLayouting) {
          newItems.forEach((item) => {
            item.classList.remove('masonry-item-pending')
          })
          this.isLayouting = false
          while (this.layoutCompleteCallbacks.length > 0) {
            const callback = this.layoutCompleteCallbacks.shift()
            callback()
          }
        }
      }, 3000)

      imagesLoaded(this.el, () => {
        clearTimeout(appendSafetyTimer)
        if (this.masonry) {
          this.masonry.layout()

          // Double rAF: let browser commit the positioned paint before revealing items.
          // This ensures masonry-item-pending is removed only after inline left/top
          // are set, so items are never visible in static document flow.
          requestAnimationFrame(() => {
            requestAnimationFrame(() => {
              newItems.forEach((item) => {
                item.classList.remove('masonry-item-pending')

                const dropCard = item.querySelector('.drop-card')
                if (
                  dropCard &&
                  !dropCard.classList.contains('animation-complete')
                ) {
                  dropCard.classList.add('animation-complete')
                }
              })
            })
          })
        } else {
          // Masonry was destroyed mid-flight (reconnect / search reset fired between
          // the rAF and imagesLoaded resolution). Reveal items unconditionally so they
          // are never left permanently hidden.
          newItems.forEach((item) => {
            item.classList.remove('masonry-item-pending')
          })
        }
        this.isLayouting = false
      })
    }
  },

  layoutWithImageLoading() {
    this.isLayouting = true

    // Safety timeout: if imagesLoaded never fires (e.g. image request hangs),
    // unblock isLayouting after 3 seconds so InfiniteScroll can proceed.
    const safetyTimer = setTimeout(() => {
      if (this.isLayouting) {
        this.isLayouting = false
        while (this.layoutCompleteCallbacks.length > 0) {
          const callback = this.layoutCompleteCallbacks.shift()
          callback()
        }
      }
    }, 3000)

    imagesLoaded(this.el, () => {
      clearTimeout(safetyTimer)
      if (this.masonry) {
        // Force a complete layout recalculation; layoutComplete event drains
        // layoutCompleteCallbacks after layout() finishes.
        this.masonry.layout()
        // layoutComplete fires async after layout(); set isLayouting=false here
        // too so waitForLayoutComplete() callers that check the flag directly resolve.
        this.isLayouting = false
        while (this.layoutCompleteCallbacks.length > 0) {
          const callback = this.layoutCompleteCallbacks.shift()
          callback()
        }
      }
    })
  },

  waitForLayoutComplete() {
    return new Promise((resolve) => {
      if (!this.isLayouting) {
        resolve()
      } else {
        // Bail out after 600ms so InfiniteScroll.loadMore() does not block
        // indefinitely when imagesLoaded is slow (e.g. external avatar URLs).
        // Flash prevention in updated() (masonry-item-pending) is unconditional
        // and does not depend on this wait completing.
        const bail = setTimeout(resolve, 600)
        this.layoutCompleteCallbacks.push(() => {
          clearTimeout(bail)
          resolve()
        })
      }
    })
  },

  sendViewportDimensions() {
    this.pushEvent('update_viewport', {
      width: window.innerWidth,
      height: window.innerHeight,
    })
  },

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }

      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  },
}

export default MasonryHooks
