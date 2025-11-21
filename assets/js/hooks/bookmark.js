let BookmarkHooks = {}

BookmarkHooks.Bookmark = {
  mounted() {
    const bookmarkButton = this.el

    bookmarkButton.addEventListener('click', (event) => {
      event.stopPropagation()

      const dropId = bookmarkButton.dataset.dropId
      const eventName = bookmarkButton.dataset.eventName
      const userId = bookmarkButton.dataset.userId

      this.pushEvent(eventName, { drop_id: dropId, user_id: userId })
    })

    this.handleEvent(
      'show_add_bookmark_btn',
      ({ add_bookmark_container_id, remove_bookmark_container_id }) => {
        const addBookmarkContainer = document.getElementById(
          add_bookmark_container_id
        )
        const removeBookmarkContainer = document.getElementById(
          remove_bookmark_container_id
        )

        addBookmarkContainer.classList.remove('hidden')
        removeBookmarkContainer.classList.add('hidden')
      }
    )

    this.handleEvent(
      'show_remove_bookmark_btn',
      ({ add_bookmark_container_id, remove_bookmark_container_id }) => {
        const addBookmarkContainer = document.getElementById(
          add_bookmark_container_id
        )
        const removeBookmarkContainer = document.getElementById(
          remove_bookmark_container_id
        )

        removeBookmarkContainer.classList.remove('hidden')
        addBookmarkContainer.classList.add('hidden')
      }
    )
  },
}

export default BookmarkHooks
