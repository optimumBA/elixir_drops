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

    if (!this.el.querySelector('.grid-sizer')) {
      const gridSizer = document.createElement('div')
      gridSizer.className = 'grid-sizer'
      this.el.prepend(gridSizer)
    }

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
