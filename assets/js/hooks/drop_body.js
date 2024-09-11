import ClipboardJS from 'clipboard'

let DropBodyHooks = {}

DropBodyHooks.DropBodyContainer = {
  mounted() {
    const container = this.el

    const createCopyPrompt = () => {
      const copyPromptTemplateEl = document.querySelector(
        '#copy-prompt-template'
      )
      const copyPrompt = document.importNode(copyPromptTemplateEl.content, true)

      return copyPrompt.firstElementChild
    }

    const codeBlocks = container.querySelectorAll('pre')

    codeBlocks.forEach((codeBlock) => {
      const copyPrompt = createCopyPrompt()

      codeBlock.insertAdjacentElement('beforebegin', copyPrompt)

      new ClipboardJS(copyPrompt, {
        text: () => codeBlock.querySelector('code').textContent,
      })

      copyPrompt.addEventListener('click', () => {
        document.querySelector('.copy-svg').classList.add('hidden')
        document.querySelector('.copied-svg').classList.remove('hidden')

        setTimeout(() => {
          document.querySelector('.copy-svg').classList.remove('hidden')
          document.querySelector('.copied-svg').classList.add('hidden')
        }, 800)
      })
    })
  },
}

DropBodyHooks.CreatePostButtonMobile = {
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
