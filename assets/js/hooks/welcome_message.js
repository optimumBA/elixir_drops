let WelcomeMessageHooks = {}

// Persist the dismissal in a cookie (not localStorage) so the server can read it
// on the dead render and keep the welcome banner hidden from the first paint,
// avoiding a flash when the LiveView connects. Absent cookie = show (the server
// default), so we only ever need to write "false".
WelcomeMessageHooks.WelcomeMessage = {
  mounted() {
    const welcomeMessage = this.el

    welcomeMessage.addEventListener('hide-welcome-message', () => {
      const oneYear = 60 * 60 * 24 * 365
      document.cookie = `show_welcome_message=false; path=/; max-age=${oneYear}; SameSite=Lax`
    })
  },
}

export default WelcomeMessageHooks
