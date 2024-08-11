let DropEditorHooks = {}

DropEditorHooks.DropBodyEditorHook = {
  mounted() {
    const hook = this
    const editor = this.el
    const fileTypeErrorMessage = document.querySelector('#file-type-error-msg')
    const uploadFileButton = document.querySelector('#upload-file-button')
    const uploadFileInput = document.querySelector('#upload-file-input')

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
      'image/gif',
      'image/jpeg',
      'image/jpg',
      'image/png',
    ]

    editor.addEventListener('dragover', cancelDefault)
    editor.addEventListener('dragleave', cancelDefault)

    const sendUploadRequest = (file) => {
      return new Promise((resolve, reject) => {
        const reader = new FileReader()

        reader.onload = () => {
          const image = reader.result

          hook.pushEvent(
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
                reject(`Failed to upload ${file.name} \n\n`)
              }
            }
          )
        }

        reader.readAsDataURL(file)
      })
    }

    const updateImageString = (imageString, newImageString) => {
      editor.value = editor.value.replace(imageString, newImageString)
      editor.dispatchEvent(new Event('input', { bubbles: true }))
    }

    const uploadFile = (file) => {
      if (acceptedFileTypes.includes(file.type.toLowerCase())) {
        fileTypeErrorMessage.classList.add('hidden')

        let imageString = `[uploading! ${file.name}...]\n\n`

        updateEditorValue(editor, imageString)

        return sendUploadRequest(file)
          .then((newImageString) => {
            updateImageString(imageString, newImageString)
          })
          .catch((error) => {
            hook.pushEvent('show-image-upload-error')
            updateImageString(imageString, error)
          })
      } else {
        fileTypeErrorMessage.classList.remove('hidden')
        return
      }
    }

    editor.addEventListener('drop', (event) => {
      cancelDefault(event)

      const file = event.dataTransfer.files[0]

      uploadFile(file)
    })

    uploadFileButton.addEventListener('click', () => {
      uploadFileInput.click()
    })

    uploadFileInput.addEventListener('change', (event) => {
      const file = event.target.files[0]

      uploadFile(file)
    })
  },
}

export default DropEditorHooks
