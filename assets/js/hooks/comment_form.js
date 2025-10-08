let CommentFormHooks = {}

CommentFormHooks.CommentForm = {
  mounted() {
    const form = this.el

    this.handleEvent('edit_comment', (event) => {
      form.classList.remove('hidden')
      form.classList.add('block')
    })

    this.handleEvent('cancel_comment', () => {
      const active = document.activeElement
      if (active && typeof active.blur === 'function') {
        active.blur()
      }
    })
  },
}

export default CommentFormHooks
