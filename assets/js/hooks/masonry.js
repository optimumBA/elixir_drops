import Masonry from 'masonry-layout'
import imagesLoaded from 'imagesloaded'

let MasonryHooks = {}

MasonryHooks.Masonry = {
  mounted() {
    this.masonry = null
    this.isLayouting = false
    this.layoutCompleteCallbacks = []

    this.sendViewportDimensions()

    setTimeout(() => {
      this.initializeMasonry()
    }, 100)

    this.handleResize = this.debounce(() => {
      this.sendViewportDimensions()
      if (this.masonry) {
        this.masonry.layout()
      }
    }, 300)

    this.handleItemRemove = (event) => {
      const dropId = event.detail?.dropId
      if (dropId) {
        const dropCard = document.querySelector(`#drop-card-${dropId}`)
        if (dropCard) {
          const masonryItem = dropCard.closest('.masonry-item')
          if (masonryItem && this.el.contains(masonryItem) && this.masonry) {
            this.masonry.remove(masonryItem)
            this.masonry.layout()
          }
        }
      }
    }

    window.addEventListener('resize', this.handleResize)
    window.addEventListener('masonry-item-remove', this.handleItemRemove)
  },

  updated() {
    // Delay to ensure DOM is fully updated
    if (this.masonry) {
      // Destroy and reinitialize for major updates (like stream resets)
      const items = this.el.querySelectorAll('.masonry-item')
      if (items.length > 0) {
        setTimeout(() => {
          this.layoutWithImageLoading()
        }, 150)
      }
    } else {
      setTimeout(() => {
        this.initializeMasonry()
      }, 150)
    }
  },

  destroyed() {
    window.removeEventListener('resize', this.handleResize)
    window.removeEventListener('masonry-item-remove', this.handleItemRemove)
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

    this.layoutWithImageLoading()
  },

  layoutWithImageLoading() {
    this.isLayouting = true

    // First reload items to pick up any new DOM elements
    if (this.masonry) {
      this.masonry.reloadItems()
    }

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
