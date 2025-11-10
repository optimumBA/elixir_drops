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

      const addBookmarkContainer = document.getElementById(
        `add-bookmark-${dropId}-${userId}`
      )
      const removeBookmarkContainer = document.getElementById(
        `remove-bookmark-${dropId}-${userId}`
      )

      if (eventName === 'bookmark_drop') {
        addBookmarkContainer.classList.add('hidden')
        removeBookmarkContainer.classList.remove('hidden')
      } else if (eventName === 'remove_from_bookmark') {
        removeBookmarkContainer.classList.add('hidden')
        addBookmarkContainer.classList.remove('hidden')
      }

      this.pushEvent(eventName, { drop_id: dropId, user_id: userId })
    })
  },
}

export default BookmarkHooks
