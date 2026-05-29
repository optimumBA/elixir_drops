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

      // Warm reconnect: masonry already positioned — restore masonry-ready
      // (LV strips it during DOM patch because the server never renders it)
      // and re-layout without full teardown.
      if (this.masonry) {
        this.sendViewportDimensions()
        this.el.classList.add('masonry-ready')
        this.masonry.layout()
        return
      }

      // Cold start or search reset: full re-init
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

    this.isLayouting = false
    this.layoutCompleteCallbacks = []
    this.trackedItems = new Set()

    if (this.el._eagerMasonry) {
      // Eager pre-connect init already ran — take ownership without re-initialising.
      this.masonry = this.el._eagerMasonry
      this.el._eagerMasonry = null
      this.el
        .querySelectorAll('.masonry-item')
        .forEach((el) => this.trackedItems.add(el.id))
      this.el
        .querySelectorAll('.drop-card')
        .forEach((el) => el.classList.add('animation-complete'))
      // Re-layout synchronously: LV's morphdom may have cleared inline left/top from items.
      // Doing this in mounted() (same JS task as the DOM patch) means the browser never
      // paints the stacked-at-origin state.
      this.masonry.layout()
      // Wire up layoutComplete so re-layouts can restore masonry-ready.
      this.masonry.on('layoutComplete', () => {
        this.isLayouting = false
        if (!this.el.classList.contains('masonry-ready')) {
          requestAnimationFrame(() =>
            requestAnimationFrame(() => this.el.classList.add('masonry-ready'))
          )
        }
        while (this.layoutCompleteCallbacks.length > 0)
          this.layoutCompleteCallbacks.shift()()
      })
    } else {
      this._mountedTimer = requestAnimationFrame(() => {
        this._mountedTimer = null
        this.initializeMasonry()
      })
    }
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
          setTimeout(() => {
            this.appendNewItems(newItems)
          }, 150)
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

      imagesLoaded(this.el, () => {
        if (this.masonry) {
          this.masonry.layout()

          setTimeout(() => {
            newItems.forEach((item) => {
              const dropCard = item.querySelector('.drop-card')
              if (!dropCard.classList.contains('animation-complete')) {
                dropCard.classList.add('animation-complete')
              }
            })
          }, 500)
        }
        this.isLayouting = false
      })
    }
  },

  layoutWithImageLoading() {
    this.isLayouting = true

    imagesLoaded(this.el, () => {
      if (this.masonry) {
        // Force a complete layout recalculation
        this.masonry.layout()
        this.isLayouting = false
      }
    })
  },

  waitForLayoutComplete() {
    return new Promise((resolve) => {
      if (!this.isLayouting) {
        resolve()
      } else {
        this.layoutCompleteCallbacks.push(resolve)
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
