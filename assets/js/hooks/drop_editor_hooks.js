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

    const acceptedFileTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/jpg',
      'image/gif',
    ]

    const fileTypeErrorMessage = document.querySelector('#file-type-error-msg')

    editor.addEventListener('dragover', cancelDefault)
    editor.addEventListener('dragleave', cancelDefault)

    const sendUploadRequest = (file) => {
      return new Promise((resolve) => {
        const reader = new FileReader()

        reader.onload = () => {
          const image = reader.result

          hook.pushEventTo(
            '#drops-form',
            'upload-image',
            {
              image: image,
              name: file.name,
              type: file.type,
            },
            (response) => {
              if (response.url) {
                resolve(
                  editor.selectionStart == 0
                    ? `![${file.name}](${response.url})\n\n`
                    : `![${file.name}](${response.url})`
                )
              } else {
                resolve(
                  editor.selectionStart == 0
                    ? `Image upload failed \n\n`
                    : `Image upload failed`
                )
              }
            }
          )
        }

        reader.readAsDataURL(file)
      })
    }

    editor.addEventListener('drop', (event) => {
      cancelDefault(event)

      const file = event.dataTransfer.files[0]

      if (acceptedFileTypes.includes(file.type.toLowerCase())) {
        fileTypeErrorMessage.classList.add('hidden')

        let imageString =
          editor.selectionStart == 0
            ? `[uploading! ${file.name}...]\n\n`
            : `[uploading! ${file.name}...]`

        updateEditorValue(editor, imageString)

        return sendUploadRequest(file).then((newImageString) => {
          editor.value = editor.value.replace(imageString, newImageString)

          editor.dispatchEvent(new Event('input', { bubbles: true }))
        })
      } else {
        fileTypeErrorMessage.classList.remove('hidden')
        return
      }
    })
  },
}

export default DropEditorHooks
