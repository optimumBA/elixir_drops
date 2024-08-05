let CopyToClipboardHooks = {}

CopyToClipboardHooks.CopyToClipboard = {
  mounted() {
    const copyLink = this.el
    let copyConfirmElement = document.querySelector(`#copy-confirm-message`)

    let textToCopy = copyLink.dataset.clipboardText

    copyLink.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()

      navigator.clipboard.writeText(textToCopy)

      copyConfirmElement.classList.remove('hidden')

      setTimeout(() => {
        copyConfirmElement.classList.add('hidden')
      }, 500)
    })
  },
}

export default CopyToClipboardHooks
