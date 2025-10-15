let CommentFormHooks = {}

CommentFormHooks.CommentForm = {
  mounted() {
    this.handleEvent('edit_comment', ({ comment_id }) => {
      const container = document.getElementById(
        `edit-comment-container-${comment_id}`
      )
      if (!container) return
      container.classList.remove('hidden')
      container.classList.add('block')
    })

    this.handleEvent('cancel_comment', () => {
      const active = document.activeElement
      if (active && typeof active.blur === 'function') {
        active.blur()
      }
    })

    this.handleEvent('reply_char_count', ({ count, form_id }) => {
      const span = document.getElementById(`${form_id}-char-count`)
      span.textContent = count
    })
  },
}

export default CommentFormHooks
