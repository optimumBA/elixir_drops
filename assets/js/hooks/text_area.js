let TextAreaHooks = {}

TextAreaHooks.TextArea = {
  mounted() {
    this.resize = () => {
      this.el.style.height = '20px'
      this.el.style.height = `${this.el.scrollHeight}px`
    }

    this.el.addEventListener('input', this.resize)
    this.resize()

    window.addEventListener('resize', this.resize)

    if ('ResizeObserver' in window) {
      this._resizeObserver = new ResizeObserver(() => this.resize())
      this._resizeObserver.observe(this.el)
    }
  },

  updated() {
    this.resize && this.resize()
  },

  destroyed() {
    this.el.removeEventListener('input', this.resize)
    window.removeEventListener('resize', this.resize)
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
  },
}

export default TextAreaHooks
