export default {
  SearchSuggestions: {
    mounted() {
      this.debounceTimer = null
      this.input = this.el.querySelector('input[name="query"]')
      this.isActive = false

      // Check if this search input is visible
      const checkIfActive = () => {
        const isMobile = this.el.closest('#search-overlay')
        const isDesktop = this.el.id === 'desktop-search-input'
        const isProfile = this.el.id === 'profile-search-input'

        if (isMobile) {
          const overlay = this.el.closest('#search-overlay')
          this.isActive = overlay && !overlay.classList.contains('hidden')
        } else if (isDesktop) {
          // Desktop search is active only when viewport is >= 1024px
          this.isActive = window.innerWidth >= 1024
        } else if (isProfile) {
          // Profile search is always active when on profile page
          this.isActive = true
        }
      }

      // Initial check
      checkIfActive()

      // Handle viewport resize
      this.handleResize = () => checkIfActive()
      window.addEventListener('resize', this.handleResize)

      // Handle overlay visibility changes
      this.handleOverlayChange = () => checkIfActive()
      window.addEventListener('search-overlay-opened', this.handleOverlayChange)
      window.addEventListener('search-overlay-closed', this.handleOverlayChange)

      // Handle input changes with debounce
      this.handleInput = (e) => {
        if (!this.isActive) return

        clearTimeout(this.debounceTimer)
        this.debounceTimer = setTimeout(() => {
          // Determine which event to push based on the input location
          const eventName =
            this.el.id === 'profile-search-input'
              ? 'load_suggestions'
              : 'load_navbar_suggestions'

          if (e.target.value.trim().length >= 2) {
            this.pushEvent(eventName, { query: e.target.value })
          } else {
            this.pushEvent(eventName, { query: '' })
          }
        }, 100)
      }

      this.input.addEventListener('input', this.handleInput)

      // Handle focus to show suggestions
      this.handleFocus = (e) => {
        checkIfActive()
        if (!this.isActive) return

        // Determine which focus event to push based on the input location
        let focusEvent
        if (this.el.id === 'profile-search-input') {
          focusEvent = 'focus_search_input'
        } else if (this.el.id === 'mobile-search-input') {
          focusEvent = 'focus_search_input'
        } else {
          focusEvent = 'focus_navbar_search'
        }

        this.pushEvent(focusEvent)
      }
      this.input.addEventListener('focus', this.handleFocus)

      // Handle blur with a delay to allow clicks on suggestions
      this.handleBlur = (e) => {
        // Check if the blur is moving to an element within the dropdown
        let dropdownId
        if (this.el.id === 'profile-search-input') {
          dropdownId = '#profile-search-dropdown'
        } else if (this.el.id === 'mobile-search-input') {
          dropdownId = '#mobile-search-dropdown'
        } else {
          dropdownId = '#navbar-search-dropdown'
        }
        const dropdown = document.querySelector(dropdownId)

        // If the related target (where focus is going) is within the dropdown, don't close it
        if (e.relatedTarget && dropdown && dropdown.contains(e.relatedTarget)) {
          return
        }

        // Delay to allow clicks on suggestions to register before hiding
        setTimeout(() => {
          // Determine which blur event to push based on the input location
          let blurEvent
          if (this.el.id === 'profile-search-input') {
            blurEvent = 'blur_search_input'
          } else if (this.el.id === 'mobile-search-input') {
            blurEvent = 'blur_search_input'
          } else {
            blurEvent = 'blur_navbar_search'
          }

          this.pushEvent(blurEvent)
        }, 200)
      }
      this.input.addEventListener('blur', this.handleBlur)

      // Simple Escape key handler for mobile
      this.handleKeydown = (e) => {
        if (e.key === 'Escape') {
          this.pushEvent('close_search_overlay')
          this.input.blur()
        }
      }

      this.input.addEventListener('keydown', this.handleKeydown)

      // Remove all manual dropdown manipulation - let Phoenix LiveView handle it via show_suggestions? state
    },

    destroyed() {
      clearTimeout(this.debounceTimer)
      window.removeEventListener('resize', this.handleResize)
      window.removeEventListener(
        'search-overlay-opened',
        this.handleOverlayChange
      )
      window.removeEventListener(
        'search-overlay-closed',
        this.handleOverlayChange
      )
      if (this.input) {
        this.input.removeEventListener('input', this.handleInput)
        this.input.removeEventListener('focus', this.handleFocus)
        this.input.removeEventListener('blur', this.handleBlur)
        this.input.removeEventListener('keydown', this.handleKeydown)
      }
    },
  },
}
