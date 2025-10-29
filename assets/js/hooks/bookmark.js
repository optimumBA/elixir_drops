let BookmarkHooks = {}

BookmarkHooks.Bookmark = {
  mounted() {
    const bookmarkButton = this.el

    bookmarkButton.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()

      const dropId = bookmarkButton.dataset.dropId
      const eventName = bookmarkButton.dataset.eventName
      const userId = bookmarkButton.dataset.userId

      this.pushEvent(eventName, { drop_id: dropId, user_id: userId })
    })
  },
}

export default BookmarkHooks
