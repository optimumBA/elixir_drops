let MasonryHooks = {}

MasonryHooks.Masonry = {
  mounted() {
    this.initMasonry()
    this.resizeObserver = new ResizeObserver(() => {
      this.layoutMasonry()
    })
    this.resizeObserver.observe(this.el)

    this.handleResize = () => this.layoutMasonry()
    window.addEventListener('resize', this.handleResize)

    this.mutationObserver = new MutationObserver(() => {
      setTimeout(() => this.layoutMasonry(), 50)
    })
    this.mutationObserver.observe(this.el, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['style', 'class'],
    })

    this.setupImageLoading()
  },

  updated() {
    setTimeout(() => this.layoutMasonry(), 100)
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }

    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }

    window.removeEventListener('resize', this.handleResize)
  },

  initMasonry() {
    this.gap = 24 // 1.5rem in pixels
    this.layoutMasonry()
  },

  getColumnCount() {
    const width = this.el.offsetWidth
    if (width >= 1024) return 3
    if (width >= 768) return 2
    return 1
  },

  setupImageLoading() {
    const images = this.el.querySelectorAll('img')
    let loadedImages = 0
    const totalImages = images.length

    if (totalImages === 0) {
      this.layoutMasonry()
      return
    }

    images.forEach((img) => {
      if (img.complete && img.naturalHeight !== 0) {
        loadedImages++
        if (loadedImages === totalImages) {
          setTimeout(() => this.layoutMasonry(), 100)
        }
      } else {
        img.addEventListener('load', () => {
          loadedImages++
          if (loadedImages === totalImages) {
            setTimeout(() => this.layoutMasonry(), 100)
          }
        })
        img.addEventListener('error', () => {
          loadedImages++
          if (loadedImages === totalImages) {
            setTimeout(() => this.layoutMasonry(), 100)
          }
        })
      }
    })
  },

  layoutMasonry() {
    const items = Array.from(this.el.children).filter(
      (child) =>
        !child.id?.includes('infinite-scroll-marker') &&
        !child.classList.contains('drops-empty')
    )

    if (items.length === 0) return

    const columnCount = this.getColumnCount()

    const containerStyle = window.getComputedStyle(this.el)
    const paddingLeft = parseInt(containerStyle.paddingLeft) || 0
    const paddingRight = parseInt(containerStyle.paddingRight) || 0
    const paddingTop = parseInt(containerStyle.paddingTop) || 0
    const availableWidth = this.el.offsetWidth - paddingLeft - paddingRight

    const columnWidth =
      (availableWidth - this.gap * (columnCount - 1)) / columnCount

    const columnHeights = new Array(columnCount).fill(paddingTop)

    this.el.style.position = 'relative'
    this.el.style.width = '100%'

    items.forEach((item, index) => {
      const shortestColumnIndex = columnHeights.indexOf(
        Math.min(...columnHeights)
      )

      const x = paddingLeft + shortestColumnIndex * (columnWidth + this.gap)
      const y = columnHeights[shortestColumnIndex]

      item.style.position = 'absolute'
      item.style.left = `${x}px`
      item.style.top = `${y}px`
      item.style.width = `${columnWidth}px`
      item.style.transition = 'all 0.3s ease'

      const itemHeight = item.offsetHeight
      columnHeights[shortestColumnIndex] += itemHeight + this.gap
    })

    const maxHeight = Math.max(...columnHeights)
    const paddingBottom = parseInt(containerStyle.paddingBottom) || 0
    this.el.style.height = `${maxHeight + paddingBottom}px`
  },
}

export default MasonryHooks
