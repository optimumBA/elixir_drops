let DropsContainerHooks = {}

DropsContainerHooks.DropsContainer = {
  mounted() {
    const hook = this
    const dropsContainer = hook.el

    dropsContainer.addEventListener('scroll-to-top', () => {
      const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
      window.scrollTo({ top: 0, behavior: reduceMotion ? 'auto' : 'smooth' })
    })
  },
}
export default DropsContainerHooks
