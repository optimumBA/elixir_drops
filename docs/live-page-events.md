# Shared LiveView page events

`ElixirDropsWeb.LiveHelpers.on_mount/4` attaches a shared `handle_event` hook
when loading notifications for the home feed, Drop detail and account Drop list.
The hook handles notification-read events for those pages and viewport/pagination
events for the two feeds. It halts only handled events; other events continue to
the page callback. In particular, Drop-detail comment pagination remains local.

Connection subscriptions remain in each page's `on_connect/1`. The resumed
LiveView fork skips mount/params callbacks on warm connections, so shared event
handling and subscriptions must be verified through an actual resumed socket.

Run the affected LiveView tests, then creation/realtime, masonry, mobile and
sponsor browser regressions with `FEATURE_TESTS=true`. Use the repository's
pinned environment and an isolated test database/port. A rendered HTML response
alone does not verify these event handlers. The normal `make ci` gate excludes
feature-tagged browser tests; run them explicitly.

When changing the hook, preserve page-specific event fallthrough, guest behavior,
notification isolation, sponsor acknowledgments and feed pagination. An event
with a matching name on a different page is not automatically shared.
