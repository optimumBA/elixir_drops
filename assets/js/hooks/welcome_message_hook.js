let WelcomeMessageHooks = {}

WelcomeMessageHooks.WelcomeMessage = {
  mounted() {
    const hook = this
    const welcomeMessage = hook.el

    const header = document.querySelector('.header')
    header.classList.remove('shadow-md')
    header.classList.remove('shadow-[#c4c0c8]')

    welcomeMessage.addEventListener('hide-welcome-message', () => {
      localStorage.setItem('show-welcome-message', 'false')
    })
  },
}

export default WelcomeMessageHooks
