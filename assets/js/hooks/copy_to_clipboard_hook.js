let CopyToClipboardHooks = {}

CopyToClipboardHooks.CopyToClipboard = {
  mounted() {
    const copyLink = this.el
    const dropid = copyLink.dataset.dropId
    let copyConfirmElement = document.querySelector(
      `#copy-confirm-message-${dropid}`
    )

    let textToCopy = copyLink.dataset.clipboardText

    copyLink.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()

      navigator.clipboard.writeText(textToCopy)

      copyConfirmElement.classList.remove('hidden')

      setTimeout(() => {
        copyConfirmElement.classList.add('hidden')
      }, 1500)
    })
  },
}

export default CopyToClipboardHooks
