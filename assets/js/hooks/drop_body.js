import ClipboardJS from 'clipboard'

let DropBodyHooks = {}

DropBodyHooks.DropBodyContainer = {
  mounted() {
    this.createCopyButton()
  },

  updated() {
    this.createCopyButton()
  },

  createCopyButton() {
    const container = this.el

    const createCopyPrompt = () => {
      const copyPromptTemplateEl = document.querySelector(
        '.copy-prompt-template'
      )
      const copyPrompt = document.importNode(copyPromptTemplateEl.content, true)

      return copyPrompt.firstElementChild
    }

    const codeBlocks = container.querySelectorAll('pre')

    codeBlocks.forEach((codeBlock) => {
      const copyPrompt = createCopyPrompt()

      codeBlock.insertAdjacentElement('beforebegin', copyPrompt)

      const clipboard = new ClipboardJS(copyPrompt, {
        text: () => codeBlock.querySelector('code').textContent,
      })

      clipboard.on('success', () => {
        copyPrompt.querySelector('.copy-svg').classList.add('hidden')
        copyPrompt.querySelector('.copied-svg').classList.remove('hidden')

        setTimeout(() => {
          copyPrompt.querySelector('.copy-svg').classList.remove('hidden')
          copyPrompt.querySelector('.copied-svg').classList.add('hidden')
        }, 800)
      })
    })
  },
}

DropBodyHooks.CreateDropButtonMobile = {
  mounted() {
    const button = this.el

    window.onscroll = () => {
      if (window.scrollY > 300) {
        button.classList.add('hidden')
      } else {
        button.classList.remove('hidden')
      }
    }
  },
}

export default DropBodyHooks
