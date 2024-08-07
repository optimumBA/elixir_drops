let DropEditorHooks = {}

DropEditorHooks.DropBodyEditorHook = {
  mounted() {
    const hook = this
    const editor = this.el

    const cancelDefault = (event) => {
      event.preventDefault()
      event.stopPropagation()

      return
    }

    const updateEditorValue = (editor, imageString) => {
      editor.value =
        editor.value.substring(0, editor.selectionStart) +
        `${imageString}` +
        editor.value.substring(editor.selectionEnd, editor.value.length)

      editor.dispatchEvent(new Event('input', { bubbles: true }))
    }

    editor.addEventListener('dragover', cancelDefault)
    editor.addEventListener('dragleave', cancelDefault)

    editor.addEventListener('drop', (event) => {
      cancelDefault(event)

      const file = event.dataTransfer.files[0]

      let imageString =
        editor.selectionStart == 0
          ? `[uploading! ${file.name}...]\n\n`
          : `[uploading! ${file.name}...]`

      updateEditorValue(editor, imageString)

      const reader = new FileReader()

      this.handleEvent('image-upload-complete', (payload) => {
        let newImageString =
          editor.selectionStart == 0
            ? `![${file.name}](${payload.url})\n\n`
            : `![${file.name}](${payload.url})`

        editor.value = editor.value.replace(imageString, newImageString)

        editor.dispatchEvent(new Event('input', { bubbles: true }))
      })

      this.handleEvent('image-upload-error', (payload) => {
        let newImageString =
          editor.selectionStart == 0
            ? `Image upload failed \n\n`
            : `Image upload failed`

        editor.value = editor.value.replace(imageString, newImageString)

        editor.dispatchEvent(new Event('input', { bubbles: true }))
      })

      reader.onload = () => {
        const image = reader.result

        hook.pushEventTo('#drops-form', 'upload-image', {
          image: image,
          name: file.name,
          type: file.type,
        })
      }

      reader.readAsDataURL(file)
    })
  },
}

export default DropEditorHooks

// TODO: check file type first -> display error
