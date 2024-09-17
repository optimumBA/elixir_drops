let DropsContainerHooks = {}

DropsContainerHooks.DropsContainer = {
  mounted() {
    const hook = this
    const dropsContainer = hook.el

    dropsContainer.addEventListener('scroll-to-top', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    })
  },
}
export default DropsContainerHooks
