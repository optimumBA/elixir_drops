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

    this.handleEvent('load_masonry', ({}) => {
      this.masonry = null
      this.isLayouting = false
      this.layoutCompleteCallbacks = []
      this.trackedItems = new Set()

      this.sendViewportDimensions()

      setTimeout(() => {
        this.initializeMasonry()
      }, 100)
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
    } else {
      setTimeout(() => {
        this.initializeMasonry()
      }, 100)
    }
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize)
    if (this.masonry) {
      this.masonry.destroy()
    }
  },

  initializeMasonry() {
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

      while (this.layoutCompleteCallbacks.length > 0) {
        const callback = this.layoutCompleteCallbacks.shift()
        callback()
      }
    })

    const items = this.el.querySelectorAll('.masonry-item')
    items.forEach((item) => {
      this.trackedItems.add(item.id)
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

        setTimeout(() => {
          const dropCards = this.el.querySelectorAll('.drop-card')

          dropCards.forEach((card) => {
            if (!card.classList.contains('animation-complete')) {
              card.classList.add('animation-complete')
            }
          })
        }, 500)
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
    this.pushEvent('update-viewport', {
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
