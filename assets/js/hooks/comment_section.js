let CommentSectionHooks = {}

// Reveals the exact comment or reply a "View in discussion" link points at.
// Lives on the comments container so it also works for guests, who have no
// comment form. The Drop page loads the conversation through the target's thread.
CommentSectionHooks.CommentSection = {
  mounted() {
    this.handleEvent('show_comment', ({ comment_id, parent_id }) => {
      this.revealComment(comment_id, parent_id)
    })

    const params = new URLSearchParams(window.location.search)
    const commentId = params.get('comment_id')
    if (commentId) this.revealComment(commentId, params.get('comment_parent_id'))
  },

  revealComment(commentId, parentId) {
    const comment = document.getElementById(`comment-${commentId}`)
    if (!comment || !this.el.contains(comment)) return

    if (parentId) {
      const replyContainer = document.getElementById(`comment-replies-${parentId}`)
      if (replyContainer && this.el.contains(replyContainer)) {
        replyContainer.classList.remove('hidden')
        replyContainer.classList.add('block')
      }
    }

    // A live navigation scrolls the page back to the top shortly after the
    // join, which would undo an immediate scroll. Keep scrolling the target
    // into view until it stays inside the viewport.
    let tries = 0
    const attempt = () => {
      comment.scrollIntoView({ block: 'center' })
      tries++
      const r = comment.getBoundingClientRect()
      const inView = r.top >= 0 && r.bottom <= window.innerHeight
      if (!inView && tries < 30) setTimeout(attempt, 100)
    }
    requestAnimationFrame(attempt)
  },
}

export default CommentSectionHooks
