# Start the clipboard status empty

Slug: clipboard-status-starts-empty
Model: not applicable — the change is static markup text and one hook cleanup step with no multi-step state worth modelling
Acceptance:
- .kogen/intents/clipboard-status-starts-empty/acceptance.feature
- features/steps/clipboard-status-starts-empty__status.js

This corrects a regression in the accepted interaction delivery (Issue eb51d7cd-e834-4f0c-8152-7ab4d28643fc, original delivery e15e1c5e-76da-4871-8b3e-91dc0fc93871; the original native contract is `.kogen/intents/ui-interaction-20261116/intent.md` and stays intact). The polite live status `#copy-confirm-message` is rendered with the prefilled text "Link copied to clipboard" inside an `sr-only` `role="status" aria-live="polite"` region, so a success claim is exposed to assistive technology before any copy happens (observed at 1440px and 390px as an initial accessibility-tree entry "status: Link copied to clipboard"; the earlier baseline used `hidden` and exposed nothing). This is an accessibility-tree observation, not proof of audible screen-reader behaviour.

Required behaviour: the status element keeps `id="copy-confirm-message"`, `role="status"`, `aria-live="polite"` and its `sr-only` idle class, but its text span `#copy-confirm-text` is rendered empty. Before any copy action or clipboard event the status contains no success or failure text. After a real ClipboardJS success callback it shows "Link copied to clipboard"; after a real error callback it shows "Copy failed. Select the link and copy it manually."; each result replaces the previous text so an earlier success is never shown for a later failed copy. The existing 500 ms visual lifecycle (visible, then `sr-only` again) is kept, and when it ends the text is cleared so the idle status is empty again. Clicking the copy button alone claims nothing. Copy buttons stay named `<button type="button">` elements and normal copy behaviour is unchanged. Do not remove the live-region semantics, use `hidden`/`aria-hidden`/`display:none`, or report success before the actual callback.

Out of scope: authorization, sign-in/OAuth, contribution routes, content, branding, sponsor/legal text, dependencies and unrelated controls.

Production edits: `lib/elixir_drops_web/live/drop_components.ex` (`copied_link_popup_message/1`) and `assets/js/hooks/copy_to_clipboard.js`. Add browser regression coverage in `test/elixir_drops_web/features/accessible_controls_test.exs` (the existing "copy actions and clipboard feedback" describe): at both a 1440px-wide and a 390px-wide viewport, assert the status is present with role/aria-live and has empty text before any event; then drive the real user copy control and the real hook success and error paths with the clipboard outcome controlled in the isolated browser (for example by stubbing `document.execCommand('copy')` to return true or false) and assert the appropriate text appears, that a later failure never shows the earlier success, and that the status returns to empty. This is accessibility-tree/DOM evidence only, not full screen-reader or audio coverage. Keep all existing browser regressions and project gates unchanged.

## Decisions
- Keep the polite live region element and its semantics, and make the initial text empty instead of hiding the element. (decision: D1, round 1) (constraint: role="status" and aria-live="polite" stay on #copy-confirm-message; no hidden, aria-hidden or display:none) (evidence: lib/elixir_drops_web/live/drop_components.ex; .kogen/intents/ui-interaction-20261116/intent.md) (source: request)
- The hook clears the status text when the 500 ms visual lifecycle ends, so the idle status returns to the initial empty state and a stale result is never exposed or reused. (decision: D2, round 1) (constraint: timing stays 500 ms; success and error texts unchanged) (evidence: assets/js/hooks/copy_to_clipboard.js) (assumption: Clearing text at lifecycle end is the chosen way to avoid a stale result remaining in the accessibility tree; announcement in real screen readers is not verified.) (source: request)
- Acceptance loads the real component source to derive the initial status markup and runs the real hook in a node vm with a fake ClipboardJS; browser coverage at 1440px and 390px is added by the build to the existing Playwright feature test and run by the unchanged project test gate. Real screen-reader/audio announcement and the browser-level coverage need human or project-gate evaluation and no acceptance scenario claims them. (decision: D3, round 1) (evidence: test/elixir_drops_web/features/accessible_controls_test.exs; assets/js/hooks/copy_to_clipboard.js) (assumption: The browser test with stubbed clipboard outcomes is not executed by the acceptance command.) (source: request)

## Source comparison
- Initial status exposes no success/failure text: addressed by the empty span and scenario "The live status text is rendered empty before any copy" (source: request).
- Live region semantics, named buttons and ClipboardJS success/error wiring from the ui-interaction contract: preserved, scenarios "The live status keeps its accessible semantics" and "Delivered copy-button and hook wiring are preserved" (source: request).
- Real success/error callbacks, no success reuse for a later failure: scenarios for success, error and "A prior success is not reused for a later failed copy" (source: request).
- Full screen-reader/audio coverage: not claimed (source: request).

## Tests
- Initial status text is empty: scenario "The live status text is rendered empty before any copy" (scenario)
- Live-region semantics, clipboard.on success/error wiring and named buttons are preserved: scenarios "The live status keeps its accessible semantics" and "Delivered copy-button and hook wiring are preserved" (scenario)
- Click alone claims nothing; success and error callbacks report the right text and return to empty; no stale success: the remaining acceptance scenarios running the real hook (scenario)
- Desktop (1440px) and 390px browser behaviour with controlled clipboard outcomes: extend the copy tests in test/elixir_drops_web/features/accessible_controls_test.exs (regression)
- Previously delivered interaction and accessibility behaviour: existing accessible_controls_test.exs and drop_components_test.exs (existing)

## Feasibility
- none
