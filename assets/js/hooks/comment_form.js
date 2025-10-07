let CommentFormHooks = {}

CommentFormHooks.CommentForm = {
  mounted() {
    const form = this.el

    this.handleEvent('edit_comment', (event) => {
      form.classList.remove('hidden')
      form.classList.add('block')
    })
  },
}

export default CommentFormHooks
