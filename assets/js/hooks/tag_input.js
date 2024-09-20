let TagInputHooks = {}

TagInputHooks.TagsInput = {
  mounted() {
    const hook = this
    const tagsInputField = hook.el
    const deleteTagBtn = document.querySelectorAll('.remove-tag')
    const dropTagsInput = document.querySelector('#drop-tags-input')

    deleteTagBtn.forEach((btn) => {
      btn.addEventListener('click', (event) => {
        event.preventDefault()
        let removeTag = event.target.parentElement

        dropTagsInput.value = dropTagsInput.value
          .split(', ')
          .filter((tag) => tag !== removeTag.innerText)
          .join(', ')
          .trim()

        dropTagsInput.dispatchEvent(new Event('input', { bubbles: true }))
      })
    })

    tagsInputField.addEventListener('keydown', (event) => {
      let tag = event.target.value.trim()

      if (tag !== '' && event.key === 'Enter') {
        event.preventDefault()
        event.stopPropagation()

        dropTagsInput.value = `${dropTagsInput.value}, ${tag}`
          .substring(0)
          .trim()
        dropTagsInput.dispatchEvent(new Event('input', { bubbles: true }))

        event.target.value = ''
      } else {
        hook.pushEventTo('#drops-form', 'suggest-tags', {
          name: event.target.value,
        })
      }
    })
  },
}

export default TagInputHooks
