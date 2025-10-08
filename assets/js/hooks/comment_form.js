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

    this.handleEvent('reply_char_count', (event) => {
      const { form_id, count } = event || {}
      if (!form_id) return
      try {
        const span = document.getElementById(`${form_id}-char-count`)
        if (span) span.textContent = String(count)
      } catch (_) {}
    })
  },
}

export default CommentFormHooks
