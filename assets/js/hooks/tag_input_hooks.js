let TagInputHooks = {}

TagInputHooks.TagsInput = {
  mounted() {
    const hook = this
    const tagsContainer = this.el
    const tagsInputField = document.querySelector("#tag-input-field")
    const deleteTagBtn = document.querySelectorAll(".remove-tag")
    const tagCountEl = document.querySelector(".tag-count")
    const tagNames = document.querySelectorAll(".tag-name")
    let tagCount = tagNames.length
    tagCountEl.textContent = `${tagCount} / 10`
    
    const addTag = (tagText) => {
      const tagTemplate = document.querySelector("#tag-template")
      const newTag = tagTemplate.content.cloneNode(true)
      newTag.querySelector(".tag-name").textContent = tagText
      tagsContainer.insertBefore(newTag, tagsInputField)
      updateTags(+1)
    }

    // Update the count of tags, if > 10 add error messages, also check count > 2 before form is submitted
    
    const updateCount = (count) => {
      tagCount = tagCount + count
      tagCountEl.textContent = `${tagCount} / 10`
    }

    const updateTags = (count) => {
      let tags = ""

      tagNames.forEach(tagName => {
        tags = `${tags}, ${tagName.textContent}`
      })

      tags = tags.substring(1).trim()

      updateCount(count)
      
      hook.pushEventTo('#drops-form', 'update-tags', {
        tags: tags
      })
    }

    deleteTagBtn.forEach(btn => {
      btn.addEventListener('click', (event) => {
        event.preventDefault()

       let tag = btn.closest(".tag")
       tag.remove()
       updateTags(-1)
      })
    })

    tagsInputField.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && e.target.value.trim() !== "") {
        e.preventDefault()
        addTag(e.target.value.trim())
        e.target.value = ""
      }
    })
  }
}

export default TagInputHooks