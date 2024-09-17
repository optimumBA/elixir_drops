let WelcomeMessageHooks = {}

WelcomeMessageHooks.WelcomeMessage = {
  mounted() {
    const hook = this
    const welcomeMessage = hook.el

    welcomeMessage.addEventListener('hide-welcome-message', () => {
      localStorage.setItem('show-welcome-message', false)
    })
  },
}

export default WelcomeMessageHooks
