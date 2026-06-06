// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

import '@github/relative-time-element'
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import topbar from '../vendor/topbar'
import Masonry from 'masonry-layout'
import imagesLoaded from 'imagesloaded'
import CommentFormHooks from './hooks/comment_form'
import CommentModalHooks from './hooks/comment_modal'
import CopyToClipboardHooks from './hooks/copy_to_clipboard'
import DropBodyHooks from './hooks/drop_body'
import DropsContainerHooks from './hooks/drops_container'
import InfiniteScrollHooks from './hooks/infinite_scroll'
import MasonryHooks from './hooks/masonry'
import MobileSearchOverlayHooks from './hooks/mobile_search_overlay'
import ScreenshotProgressHooks from './hooks/screenshot_progress'
import SearchSuggestionsHooks from './hooks/search_suggestions'
import TextAreaHooks from './hooks/text_area'
import WelcomeMessageHooks from './hooks/welcome_message'

let Hooks = {
  ...CommentFormHooks,
  ...CommentModalHooks,
  ...CopyToClipboardHooks,
  ...DropBodyHooks,
  ...DropsContainerHooks,
  ...InfiniteScrollHooks,
  ...MasonryHooks,
  ...MobileSearchOverlayHooks,
  ...ScreenshotProgressHooks,
  ...SearchSuggestionsHooks,
  ...TextAreaHooks,
  ...WelcomeMessageHooks,
}

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

let showOrHideWelcomeMessage = () => {
  if (localStorage.getItem('show-welcome-message') === null) {
    localStorage.setItem('show-welcome-message', true)
  }

  return localStorage.getItem('show-welcome-message')
}

let params = {
  _csrf_token: csrfToken,
  show_welcome_message: showOrHideWelcomeMessage(),
}

const liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: params,
  dom: {
    onBeforeElUpdated(fromEl, toEl) {
      if (fromEl.nodeType !== 1 || !fromEl.classList) return
      if (
        fromEl.classList.contains('masonry-grid') ||
        fromEl.classList.contains('masonry-item')
      ) {
        const fromStyle = fromEl.getAttribute('style')
        if (fromStyle) toEl.setAttribute('style', fromStyle)
      }
      // Preserve JS-only masonry-ready class: server HTML never includes it, so morphdom
      // would strip it on every diff. Copy it forward so Masonry's visible state survives patches.
      if (fromEl.classList.contains('masonry-grid') && fromEl.classList.contains('masonry-ready')) {
        toEl.classList.add('masonry-ready')
      }
    },
  },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', (_info) => topbar.show(300))
window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide())

// Initialize Masonry eagerly on DOMContentLoaded for dead-render drops
// so layout is correct before WebSocket connects and the hook fires.
document.addEventListener('DOMContentLoaded', () => {
  const grid = document.querySelector('.masonry-grid')
  if (!grid) return

  // Add masonry-js-init (opacity:0) immediately so grid is hidden during initial layout.
  // masonry-ready is absent until layout completes; remove it in case of warm reconnect.
  grid.classList.add('masonry-js-init')
  grid.classList.remove('masonry-ready')

  // Add grid-sizer if missing
  if (!grid.querySelector('.grid-sizer')) {
    const gridSizer = document.createElement('div')
    gridSizer.className = 'grid-sizer'
    grid.prepend(gridSizer)
  }

  const masonry = new Masonry(grid, {
    itemSelector: '.masonry-item',
    columnWidth: '.grid-sizer',
    gutter: 24,
    percentPosition: false,
    transitionDuration: '0.0s',
    stagger: 0,
  })

  imagesLoaded(grid, () => {
    masonry.layout()
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        grid.classList.add('masonry-ready')
      })
    })
  })

  // Store on element so the hook can detect and take ownership
  grid._eagerMasonry = masonry
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === 'development') {
  window.addEventListener(
    'phx:live_reload:attached',
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs()

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown
      window.addEventListener('keydown', (e) => (keyDown = e.key))
      window.addEventListener('keyup', (e) => (keyDown = null))
      window.addEventListener(
        'click',
        (e) => {
          if (keyDown === 'c') {
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtCaller(e.target)
          } else if (keyDown === 'd') {
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtDef(e.target)
          }
        },
        true
      )

      window.liveReloader = reloader
    }
  )
}
