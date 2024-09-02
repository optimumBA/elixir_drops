let TagInputHooks = {}

TagInputHooks.TagsInput = {
  mounted() {
    const hook = this
    const tagsContainer = this.el
    const deleteTagBtn = document.querySelectorAll('.remove-tag')
    const dropTagsInput = document.querySelector('#drop-tags-input')
    const tagCountEl = document.querySelector('.tag-count')
    const tagNames = document.querySelectorAll('.tag-name')
    const tagsInputField = document.querySelector('#tag-input-field')

    let tagCount = tagNames.length
    tagCountEl.textContent = `${tagCount} / 10`

    const addTag = (tagText) => {
      const tagTemplate = document.querySelector('#tag-template')
      const newTag = tagTemplate.content.cloneNode(true)
      newTag.querySelector('.tag-name').textContent = tagText
      tagsContainer.insertBefore(newTag, tagsInputField)

      let tags = dropTagsInput.value + `, ${tagText}`

      updateTags(tags, +1)
    }

    const updateCount = (count) => {
      tagCount = tagCount + count
      tagCountEl.textContent = `${tagCount} / 10`
    }

    const updateTags = (tagText, count) => {
      dropTagsInput.value = tagText

      dropTagsInput.dispatchEvent(new Event('input', { bubbles: false }))

      hook.pushEventTo('#drops-form', 'update-tags', {
        tags: dropTagsInput.value,
      })

      updateCount(count)
    }

    const debounce = (cb, delay = 1000) => {
      let timeout

      return (...args) => {
        clearTimeout(timeout)
        timeout = setTimeout(() => {
          cb(...args)
        }, delay)
      }
    }

    const updateTagSuggestions = debounce(() => {
      updateTagsList(tagsInputField)
    })

    const updateTagsList = (element) => {
      hook.pushEventTo('#drops-form', 'suggest-tags', {
        name: element.value.trim(),
      })
    }

    deleteTagBtn.forEach((btn) => {
      btn.addEventListener('click', (event) => {
        event.preventDefault()

        let tag = btn.closest('.tag')
        let tagText = tag.textContent.trim()

        let newValue = dropTagsInput.value
          .split(', ')
          .filter((text) => text !== tagText)
          .join(', ')

        updateTags(newValue, -1)

        tag.remove()
      })
    })

    tagsInputField.addEventListener('keydown', (event) => {
      if (event.target.value.trim() !== '') {
        if (event.key === 'Enter') {
          event.preventDefault()
          event.stopPropagation()

          addTag(event.target.value.trim())
          event.target.value = ''
        } else {
          updateTagSuggestions()
        }
      }
    })
  },
}

export default TagInputHooks
