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
        // Refocusing the field after Escape must not reopen the list.
        if (this.keepClosed) return
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

      const dropdownSelector = () => {
        if (this.el.id === 'profile-search-input')
          return '#profile-search-dropdown'
        if (this.el.id === 'mobile-search-input')
          return '#mobile-search-dropdown'
        return '#navbar-search-dropdown'
      }

      const getDropdown = () => document.querySelector(dropdownSelector())

      const getOptions = () => {
        const dropdown = getDropdown()
        return dropdown
          ? Array.from(dropdown.querySelectorAll('[role="option"]'))
          : []
      }

      const activeIndex = (options) =>
        options.findIndex((o) => o.getAttribute('aria-selected') === 'true')

      // Select one option (or none with -1): the input keeps DOM focus and
      // points at the selected row with aria-activedescendant.
      const setActive = (options, index) => {
        options.forEach((option, i) => {
          const selected = i === index
          option.setAttribute('aria-selected', selected ? 'true' : 'false')
          option.classList.toggle('bg-gray-100', selected)
        })

        if (index >= 0 && options[index]) {
          this.input.setAttribute('aria-activedescendant', options[index].id)
          options[index].scrollIntoView({ block: 'nearest' })
        } else {
          this.input.removeAttribute('aria-activedescendant')
        }
      }

      const closeSuggestions = () => {
        this.pushEvent('close_search_overlay')
      }

      // Arrow Up/Down move the selection, Enter activates it, Escape closes.
      this.handleKeydown = (e) => {
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
          const options = getOptions()
          if (options.length === 0) {
            // Nothing to select: ArrowDown asks for the suggestions again,
            // for example after Escape closed the list.
            if (e.key === 'ArrowDown') this.handleFocus(e)
            return
          }

          e.preventDefault()
          const current = activeIndex(options)
          let next
          if (e.key === 'ArrowDown') {
            next = current + 1 >= options.length ? 0 : current + 1
          } else {
            next = current <= 0 ? options.length - 1 : current - 1
          }
          setActive(options, next)
        } else if (e.key === 'Enter') {
          const options = getOptions()
          const current = activeIndex(options)
          if (current >= 0) {
            e.preventDefault()
            options[current].click()
          }
        } else if (e.key === 'Escape') {
          closeSuggestions()
          this.input.removeAttribute('aria-activedescendant')

          if (this.el.id === 'mobile-search-input') {
            this.input.blur()
            const close = document.querySelector('#search-overlay-close')
            if (close) close.click()
            const trigger = document.querySelector('#search-trigger')
            if (trigger) trigger.focus()
          }
        }
      }

      this.input.addEventListener('keydown', this.handleKeydown)

      // Escape inside the list (for example on a history delete button)
      // closes it and returns focus to the search field.
      this.handleListKeydown = (e) => {
        if (e.key !== 'Escape') return
        const dropdown = getDropdown()
        if (!dropdown || !dropdown.contains(e.target)) return

        e.preventDefault()
        closeSuggestions()
        this.keepClosed = true
        this.input.focus()
        this.keepClosed = false
      }

      document.addEventListener('keydown', this.handleListKeydown)

      // Remove all manual dropdown manipulation - let Phoenix LiveView handle it via show_suggestions? state
    },

    destroyed() {
      clearTimeout(this.debounceTimer)
      document.removeEventListener('keydown', this.handleListKeydown)
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
