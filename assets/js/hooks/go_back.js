let GoBackHooks = {}

GoBackHooks.GoBack = {
  mounted() {
    this.el.addEventListener('click', () => {
      // Check if there is a valid history state to go back to
      if (window.history.length > 1) {
        window.history.back()
      } else {
        console.error('No history to go back to.')
      }
    })
  },
}

export default GoBackHooks