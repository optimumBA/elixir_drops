export default {
  MobileSearchOverlay: {
    mounted() {
      // Auto-focus search input when overlay becomes visible
      this.observer = new MutationObserver(() => {
        if (!this.el.classList.contains('hidden')) {
          const input = this.el.querySelector('input[type="text"]')
          if (input) {
            setTimeout(() => input.focus(), 100)
          }
          // Dispatch event to notify SearchSuggestions hook
          window.dispatchEvent(new CustomEvent('search-overlay-opened'))
        } else {
          // Dispatch event when overlay is closed
          window.dispatchEvent(new CustomEvent('search-overlay-closed'))
        }
      })

      this.observer.observe(this.el, {
        attributes: true,
        attributeFilter: ['class'],
      })

      // Handle escape key to close overlay
      this.handleEscape = (e) => {
        if (e.key === 'Escape' && !this.el.classList.contains('hidden')) {
          this.pushEvent('close_search_overlay')
          this.el.classList.add('hidden')
        }
      }

      document.addEventListener('keydown', this.handleEscape)
    },

    destroyed() {
      if (this.observer) {
        this.observer.disconnect()
      }
      document.removeEventListener('keydown', this.handleEscape)
    },
  },
}
