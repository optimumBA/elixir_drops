let CommentFormHooks = {}

CommentFormHooks.CommentForm = {
  mounted() {
    this.handleEvent('cancel_comment', () => {
      const active = document.activeElement
      if (active && typeof active.blur === 'function') {
        active.blur()
      }
    })

    this.handleEvent('edit_comment', ({ comment_id }) => {
      const editForm = document.getElementById(
        `edit-comment-form-${comment_id}`
      )
      editForm.classList.remove('hidden')
      editForm.classList.add('block')

      const formCustomInput = document.getElementById(
        `edit-comment-form-field-${comment_id}`
      )
      formCustomInput.focus()
    })

    this.handleEvent('reply_char_count', ({ count, form_id }) => {
      const span = document.getElementById(`${form_id}-char-count`)
      span.textContent = count
      const submitButton = document.getElementById(`submit-button-${form_id}`)
      if (count > 0) {
        submitButton.disabled = false
      } else {
        submitButton.disabled = true
      }
    })
  },
}

export default CommentFormHooks
