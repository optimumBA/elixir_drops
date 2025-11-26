let CommentModalHooks = {}

CommentModalHooks.CommentModal = {
  mounted() {
    this.el.addEventListener('delete_comment', () => {
      let comment_id = this.el.dataset.commentIdPendingDeletion
      this.pushEvent('delete_comment', { comment_id: comment_id })
    })
  },
}

export default CommentModalHooks
