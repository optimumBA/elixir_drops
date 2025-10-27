let TextAreaHooks = {}

TextAreaHooks.TextArea = {
  mounted() {
    this.resize = () => {
      this.el.style.height = '20px'
      this.el.style.height = `${this.el.scrollHeight}px`
    }

    this.el.addEventListener('input', this.resize)
    this.resize()
    // Resize again next frame for accuracy with pre-filled content and fonts
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(() => this.resize())
    }

    // Recalculate when window resizes (wrap can change)
    this._onWindowResize = () => this.resize()
    window.addEventListener('resize', this._onWindowResize)

    // Observe element size changes (container width, fonts loading)
    if ('ResizeObserver' in window) {
      this._resizeObserver = new ResizeObserver(() => this.resize())
      this._resizeObserver.observe(this.el)
    }
  },

  updated() {
    this.resize && this.resize()
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(() => this.resize && this.resize())
    }
  },

  destroyed() {
    this.el.removeEventListener('input', this.resize)
    window.removeEventListener('resize', this._onWindowResize)
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
  },
}

export default TextAreaHooks
