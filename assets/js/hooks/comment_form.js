let CommentFormHooks = {}

CommentFormHooks.CommentForm = {
  mounted() {
    this.handleEvent('cancel_comment', () => {
      const active = document.activeElement
      active.blur()
    })

    this.handleEvent('show_replies', ({ comment_id, parent_id }) => {
      const replyContainer = document.getElementById(
        `comment-replies-${parent_id}`
      )
      replyContainer.classList.remove('hidden')
      replyContainer.classList.add('block')

      document
        .getElementById(`comment-${comment_id}`)
        .scrollIntoView({ behaviour: 'instant', block: 'center' })
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
      if (count > 0 && count <= 1000) {
        submitButton.disabled = false
      } else {
        submitButton.disabled = true
      }
    })
  },
}

export default CommentFormHooks
