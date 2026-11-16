import ClipboardJS from 'clipboard'

let CopyToClipboardHooks = {}

CopyToClipboardHooks.CopyToClipboard = {
  mounted() {
    const copyLink = this.el
    const copyConfirmElement = document.querySelector(`#copy-confirm-message`)
    const copyConfirmText = document.querySelector(`#copy-confirm-text`)
    let hideTimeout = null

    const showMessage = (text) => {
      if (!copyConfirmElement) return

      if (copyConfirmText) copyConfirmText.textContent = text
      copyConfirmElement.classList.remove('sr-only')

      clearTimeout(hideTimeout)
      hideTimeout = setTimeout(() => {
        copyConfirmElement.classList.add('sr-only')
      }, 500)
    }

    const clipboard = new ClipboardJS(copyLink)

    clipboard.on('success', () => showMessage('Link copied to clipboard'))
    clipboard.on('error', () =>
      showMessage('Copy failed. Select the link and copy it manually.')
    )

    copyLink.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()
    })
  },
}

export default CopyToClipboardHooks
