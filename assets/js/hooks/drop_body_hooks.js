import ClipboardJS from 'clipboard'

let DropBodyHooks = {}

DropBodyHooks.DropBodyContainer = {
  mounted() {
    const container = this.el

    const copySvg = `
      <svg width="20" height="22" viewBox="0 0 20 22" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path fill-rule="evenodd" clip-rule="evenodd" d="M13 0.25H8.944C7.106 0.25 5.65 0.25 4.511 0.403C3.339 0.561 2.39 0.893 1.641 1.641C0.893 2.39 0.561 3.339 0.403 4.511C0.25 5.651 0.25 7.106 0.25 8.944V15C0.250024 15.8934 0.568936 16.7575 1.14934 17.4367C1.72974 18.1159 2.53351 18.5657 3.416 18.705C3.553 19.469 3.818 20.121 4.348 20.652C4.95 21.254 5.708 21.512 6.608 21.634C7.475 21.75 8.578 21.75 9.945 21.75H13.055C14.422 21.75 15.525 21.75 16.392 21.634C17.292 21.512 18.05 21.254 18.652 20.652C19.254 20.05 19.512 19.292 19.634 18.392C19.75 17.525 19.75 16.422 19.75 15.055V9.945C19.75 8.578 19.75 7.475 19.634 6.608C19.512 5.708 19.254 4.95 18.652 4.348C18.121 3.818 17.469 3.553 16.705 3.416C16.5657 2.53351 16.1159 1.72974 15.4367 1.14934C14.7575 0.568936 13.8934 0.250024 13 0.25ZM15.13 3.271C14.9779 2.827 14.6909 2.44166 14.3089 2.16893C13.927 1.89619 13.4693 1.74971 13 1.75H9C7.093 1.75 5.739 1.752 4.71 1.89C3.705 2.025 3.125 2.279 2.702 2.702C2.279 3.125 2.025 3.705 1.89 4.711C1.752 5.739 1.75 7.093 1.75 9V15C1.74971 15.4693 1.89619 15.927 2.16892 16.3089C2.44166 16.6908 2.827 16.9779 3.271 17.13C3.25 16.52 3.25 15.83 3.25 15.055V9.945C3.25 8.578 3.25 7.475 3.367 6.608C3.487 5.708 3.747 4.95 4.348 4.348C4.95 3.746 5.708 3.488 6.608 3.367C7.475 3.25 8.578 3.25 9.945 3.25H13.055C13.83 3.25 14.52 3.25 15.13 3.271ZM5.408 5.41C5.685 5.133 6.073 4.953 6.808 4.854C7.562 4.753 8.564 4.751 9.999 4.751H12.999C14.434 4.751 15.435 4.753 16.191 4.854C16.925 4.953 17.313 5.134 17.59 5.41C17.867 5.687 18.047 6.075 18.146 6.81C18.247 7.564 18.249 8.566 18.249 10.001V15.001C18.249 16.436 18.247 17.437 18.146 18.193C18.047 18.927 17.866 19.315 17.59 19.592C17.313 19.869 16.925 20.049 16.19 20.148C15.435 20.249 14.434 20.251 12.999 20.251H9.999C8.564 20.251 7.562 20.249 6.807 20.148C6.073 20.049 5.685 19.868 5.408 19.592C5.131 19.315 4.951 18.927 4.852 18.192C4.751 17.437 4.749 16.436 4.749 15.001V10.001C4.749 8.566 4.751 7.564 4.852 6.809C4.951 6.075 5.132 5.687 5.408 5.41Z" fill="#EAE8FD"/>
      </svg>
    `

    const copiedSvg = `
      <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M7 10L9 12L13 8M19 10C19 14.9706 14.9706 19 10 19C5.02944 19 1 14.9706 1 10C1 5.02944 5.02944 1 10 1C14.9706 1 19 5.02944 19 10Z" stroke="#B2B2B2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    `

    const createCopyPrompt = () => {
      const copyPrompt = document.createElement('div')
      copyPrompt.classList.add('copy-prompt')

      copyPrompt.innerHTML = copySvg

      return copyPrompt
    }

    const codeBlocks = container.querySelectorAll('pre')

    codeBlocks.forEach((codeBlock) => {
      const copyPrompt = createCopyPrompt()

      codeBlock.insertAdjacentElement('beforebegin', copyPrompt)

      new ClipboardJS(copyPrompt, {
        text: () => codeBlock.querySelector('code').textContent,
      })

      copyPrompt.addEventListener('click', () => {
        copyPrompt.innerHTML = copiedSvg

        setTimeout(() => {
          copyPrompt.innerHTML = copySvg
        }, 800)
      })
    })
  },
}

DropBodyHooks.DropCardMenu = {
  mounted() {
    const button = this.el
    const dropId = button.dataset.dropId
    const dropCardMenus = document.querySelectorAll(`.drop-card-menu`)

    button.addEventListener('click', (event) => {
      event.preventDefault()
      event.stopPropagation()

      dropCardMenus.forEach((dropCardMenu) => {
        if (dropCardMenu.id === `drop-card-menu-${dropId}`) {
          dropCardMenu.classList.toggle('hidden')
        } else {
          dropCardMenu.classList.add('hidden')
        }
      })
    })
  },
}

DropBodyHooks.CreatePostButtonMobile = {
  mounted() {
    const button = this.el

    const emptyDropsEl = document.querySelector('#drops-empty')

    if (
      emptyDropsEl &&
      emptyDropsEl.parentElement.lastElementChild.id == 'drops-empty'
    ) {
      button.classList.add('hidden')
    }

    window.onscroll = () => {
      if (window.scrollY > 300) {
        button.classList.add('hidden')
      } else {
        button.classList.remove('hidden')
      }
    }
  },
}

DropBodyHooks.SecondaryNavLinks = {
  mounted() {
    const secondaryNavLinks = this.el

    const lgMediaScreensQuery = window.matchMedia('(min-width: 1280px)')

    const emptyDropsEl = document.querySelector('#drops-empty')
    const dropContainerWithDrops =
      emptyDropsEl.parentElement.lastElementChild.id.includes('drops-empty')

    if (emptyDropsEl && dropContainerWithDrops && lgMediaScreensQuery.matches) {
      secondaryNavLinks.classList.add('breakout')
    }

    if (
      emptyDropsEl &&
      !dropContainerWithDrops &&
      lgMediaScreensQuery.matches
    ) {
      secondaryNavLinks.classList.remove('breakout')
    }
  },
}

export default DropBodyHooks
