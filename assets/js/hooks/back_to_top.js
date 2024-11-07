let BackToTopHooks = {}

BackToTopHooks.BackToTopButton = {
  mounted() {
    const backToTopBtn = document.getElementById('backToTopBtn')

    if (!backToTopBtn) {
      console.error('Back to Top button not found.')
      return
    }

    const scrollFunction = () => {
      if (window.scrollY > 1000) {
        backToTopBtn.classList.remove('hidden')
        backToTopBtn.classList.add('block')
      } else {
        backToTopBtn.classList.add('hidden')
        backToTopBtn.classList.remove('block')
      }
    }

    window.addEventListener('scroll', scrollFunction)

    backToTopBtn.addEventListener('click', () => {
      window.scrollTo({
        top: 0,
        behavior: 'smooth',
      })
    })
  },
}

export default BackToTopHooks
