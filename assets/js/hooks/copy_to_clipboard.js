import ClipboardJS from 'clipboard'

let CopyToClipboardHooks = {}

CopyToClipboardHooks.CopyToClipboard = {
  mounted() {
    const copyLink = this.el
    let copyConfirmElement = document.querySelector(`#copy-confirm-message`)

    new ClipboardJS(copyLink)

    copyLink.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()

      copyConfirmElement.classList.remove('hidden')

      setTimeout(() => {
        copyConfirmElement.classList.add('hidden')
      }, 4000)
    })
  },
}

export default CopyToClipboardHooks
