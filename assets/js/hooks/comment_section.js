let CommentSectionHooks = {}

// Reveals the exact comment or reply a "View in discussion" link points at.
// Lives on the comments container so it also works for guests, who have no
// comment form. The Drop page loads the conversation through the target's
// thread, so the element is in the DOM when the event arrives.
CommentSectionHooks.CommentSection = {
  mounted() {
    this.handleEvent('show_comment', ({ comment_id, parent_id }) => {
      // if we are showing a reply we have to open the replies container
      if (parent_id != '') {
        const replyContainer = document.getElementById(
          `comment-replies-${parent_id}`
        )
        if (replyContainer) {
          replyContainer.classList.remove('hidden')
          replyContainer.classList.add('block')
        }
      }

      const comment = document.getElementById(`comment-${comment_id}`)
      if (!comment) return

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
    })
  },
}

export default CommentSectionHooks