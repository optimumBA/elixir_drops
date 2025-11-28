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

import '@github/relative-time-element'
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import topbar from '../vendor/topbar'
import BookmarkHooks from './hooks/bookmark'
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
  ...BookmarkHooks,
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

let csrfToken = document
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

let liveSocket = new LiveSocket('/live', Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: params,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', (_info) => topbar.show(300))
window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
