let GoBackHooks = {}

GoBackHooks.GoBack = {
  mounted() {
    const goBackBtn = document.getElementById('close-editor-button')

    if (!goBackBtn) {
      console.error('Go back button not found.')
      return
    }

    goBackBtn.addEventListener('click', () => {
      window.history.back()
    })
  },
}

export default GoBackHooks
