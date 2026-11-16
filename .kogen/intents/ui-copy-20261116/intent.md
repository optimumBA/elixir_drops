# Use factual, consistent reader-facing copy

Slug: ui-copy-20261116
Model: not applicable — this is a corrective copy pass over static strings and two stateless browser hooks, with no interacting state.
Acceptance:
- .kogen/intents/ui-copy-20261116/acceptance.feature
- features/steps/ui-copy-20261116__copy.js

This change replaces unsupported welcome superlatives and inconsistent or unhelpful reader-facing strings with concise, truthful copy, and makes clipboard confirmations appear only after the clipboard reports success. Product behavior, layout, auth and contribution routes, attribution, commercial terms and legal text are unchanged. It does not adopt a new tagline or logo, and adds no publishing, sponsor creative, policy text, newsletter, new feature claims or new settings.

Exact final copy (the source of truth for the Build):
- Welcome heading stays `Welcome to ElixirDrops!`. Welcome paragraph becomes exactly: `ElixirDrops is a collection of short, practical Elixir, Phoenix and OTP tips. Sign in with GitHub to share your own Drops and join the discussion.` (replaces "ultimate hub", "perfect place", "best tips and tricks").
- Login-required flash (both places in `lib/elixir_drops_web/user_auth.ex`): `Sign in to access this page.`
- Foreign or missing drop flash in `lib/elixir_drops_web/live/user_drop_live/index.ex`: `This Drop was not found, or you can only edit your own Drops.`
- GitHub auth failure flash: `GitHub sign-in did not complete. Try signing in again.`
- Comment create failure flash (only the definite `{:error, changeset}` outcome): `Your comment was not saved. Try again.`; comment update failure flash: `Your changes were not saved. Try again.`
- Flash group titles in `layouts.ex`: `Success`, `Error`. Uncertain outcomes (the socket drops or the server errors, so the result of a save in flight is unknown) must neither claim success nor loss: client disconnect notice title `Connection lost` with body `Reconnecting. If you just saved something, check that it saved before trying again.`; server error notice title `Server error` with body `Reconnecting to the server. If you just saved something, check that it saved before trying again.` The `client-error` and `server-error` elements and their phx-connected/disconnected wiring are unchanged.
- Link-copy popup: the text span gets id `copy-confirm-text` with initial text `Link copied to clipboard`; `assets/js/hooks/copy_to_clipboard.js` shows `#copy-confirm-message` only from the ClipboardJS `success` event (text `Link copied to clipboard`) or `error` event (text `Copy failed. Select the link and copy it manually.`), set via `textContent` of `#copy-confirm-text`, then hides it again from a timeout. A click alone never shows it.
- Code-block copy icon in `assets/js/hooks/drop_body.js` switches to the copied icon only from the ClipboardJS `success` event, not from the click listener, and reverts after its existing delay.
- `Create Drop` / `Update Drop` / `Comment` / `Reply` / `Cancel` labels are already literal and stay. "Drop" is capitalized when it names the product object.

Existing tests that assert replaced strings (`test/elixir_drops_web/user_auth_test.exs`, `test/elixir_drops_web/live/user_drop_live_test.exs`, and the feature tests under `test/elixir_drops_web/features/` that assert `You must log in to access this page` or `You can only edit your own drops`) are updated to the new copy.

Delivery evidence outside this Intent's executable acceptance: the issue requires inspecting every changed string in real desktop and 390px phone views; no browser is available to acceptance here, so the Build reports the exact final copy above and states honestly that rendered desktop/390px inspection is an outstanding handoff.

## Decisions
- The welcome paragraph reuses the README's own description of the product (short, practical Elixir, Phoenix and OTP tips) and keeps the invitation to sign in with GitHub. (evidence: README.md; lib/elixir_drops_web/live/drop_components.ex) (source: request)
- Use "Sign in" everywhere, matching the welcome message, instead of "log in". (evidence: lib/elixir_drops_web/user_auth.ex) (assumption: the product prefers "sign in" over "log in") (source: request)
- Link-copy confirmation is driven by ClipboardJS success/error events rather than the click, because the old hook showed it on every click regardless of outcome. (evidence: assets/js/hooks/copy_to_clipboard.js; assets/js/hooks/drop_body.js) (source: request)
- Uncertain saves (a disconnect or server error while a save is in flight) are covered by the connection notices, which say to check whether the change saved instead of claiming success or loss; "not saved" copy is used only for the definite changeset-error outcomes. (evidence: lib/elixir_drops_web/components/layouts.ex; lib/elixir_drops_web/live/drop_live/show.ex) (source: request)
- No new setting, tagline or logo is introduced. (source: request)
- Controls are deferred because the correct overlay spans many production files and existing tests. (evidence: lib/elixir_drops_web/components/layouts.ex) (assumption: The request never mentions controls; deferring them is an unrequested scope narrowing and the cited file does not show the stated reason.) (source: request)
- The linked issue text was not readable in this session; scope is derived from the request text and the strings found in the repository. (assumption: the listed strings cover the issue's scoped copy) (source: request)

## Source comparison
- Welcome superlatives: addressed in `drop_components.ex` welcome message (source: request).
- Sentence case and terminology: addressed for flash titles, auth and drop-ownership errors (source: request).
- Error text with next action: addressed for GitHub auth failure and comment create/update failures (source: request).
- Uncertain saves: addressed through the connection notices in `layouts.ex` (source: request).
- Clipboard confirmations only after success: addressed in both clipboard hooks (source: request).
- Proposed tagline, parked branch, publishing, sponsor creative, policy text, newsletter, push, deployment: omitted by request.
- Auth/contribution routes, attribution, commercial terms, legal owners: preserved; acceptance asserts the redirects and Drop form labels remain.

## Tests
- Welcome copy is factual: scenario "Welcome message states what ElixirDrops is without superlatives" (scenario)
- Sign-in and Drop terminology in flash errors: scenario "Sign-in wording and Drop terminology are consistent in flash errors", plus updated existing flash assertions in test/elixir_drops_web/user_auth_test.exs (scenario)
- Failure messages explain failure and next step: scenario "Failure messages explain what failed and what to do next" (scenario)
- Connection notices and uncertain saves: scenario "Connection notices state the connection state and do not claim a save succeeded or was lost" (scenario)
- Link-copy confirmation only after success, failure message on error: scenarios "Link copy confirmation appears only after the clipboard reports success" and "A failed copy says so instead of confirming" (scenario)
- Code-block copy success-only and popup markup: scenario "Copy popup markup and code-block copy follow the same success-only rule" (scenario)
- Routes and labels preserved: scenario "Authentication and contribution routes are preserved" (scenario)
- Existing welcome and flash tests keep passing with updated strings: existing LiveView and feature tests under test/elixir_drops_web (existing)

## Feasibility
- none
