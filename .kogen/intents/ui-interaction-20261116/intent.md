# Restore native navigation and accessible controls

Slug: ui-interaction-20261116
Model: not applicable — this is a markup and browser-hook repair of stateless interactive controls with no interacting domain state.
Acceptance:
- .kogen/intents/ui-interaction-20261116/acceptance.feature
- features/steps/ui-interaction-20261116__source.js
- features/steps/ui-interaction-20261116__negative.js

Readers can navigate and operate the shared controls with standard browser, keyboard and assistive-technology behavior, without changing authorization or normal pointer behavior.

Required outcome (the Build is held to all of it):
- Drop cards: each card exposes a visible semantic link to `/d/:short_id` (replacing the invisible empty anchor and the scripted `role="link"` plus `phx-click` navigation on the list item), so Command/Ctrl-click, middle-click, context menu and keyboard activation work natively. A plain pointer click anywhere on the card still opens the Drop, and actions in the nested card menu (menu button, Copy Drop link, Copy Markdown URL, view as Markdown, edit) never navigate the card.
- Copy actions (`phx-hook="CopyToClipboard"`) are `<button type="button">` elements with visible or `aria-label` names. The account (avatar), notification (mobile and desktop) and search triggers are `<button>` elements with an accessible name and an accurate `aria-expanded` (updated when toggled, e.g. with `JS.toggle_attribute`); the card menu and action-row menu buttons carry `aria-expanded` and `aria-controls`. Every icon-only button has an `aria-label`.
- Search suggestions (navbar, mobile overlay and profile) are a `role="listbox"` of `role="option"` rows with Arrow Up/Down selection, Enter activation and Escape close in `assets/js/hooks/search_suggestions.js`; rows are no longer `tabindex="0"` divs with only a click handler. The history-delete button has an `aria-label` and becomes visible on focus (focus variant next to `group-hover`), not only on hover. Existing search/delete events stay unchanged.
- Help that appears only on hover is also available on focus; the only hover-only reveal in the current markup is the history-delete button (above), and icon-only controls get accessible names.
- Dialogs: the sign-in popup, the leave-editor confirmation and the screenshot-progress popup get `role="dialog"` (or `alertdialog`), `aria-modal="true"`, an accessible name, initial focus on show, focus contained while open, Escape close and focus return to the trigger. `show_modal` in `core_components.ex` records focus with `JS.push_focus()` so `hide_modal`'s existing `JS.pop_focus()` returns it. Click-away close is preserved.
- Clipboard feedback keeps following the real ClipboardJS success/error result (already so in `copy_to_clipboard.js`) and `#copy-confirm-message` becomes a polite live region (`role="status"`, `aria-live="polite"`) so the result is announced.
- Images: every `<img>` in `drop_components.ex` has an `alt`. Screenshot previews get a useful alternative derived from the Drop title; avatars next to a visible username, images inside a named button and the logo in the sign-in popup are decorative with `alt=""`; the three `alt="notification icon"` images are decorative inside the named notification button.

Boundaries: authorization, the OAuth/sign-in flow, contribution routes, comment code, author permissions, click-away close, logos/taglines, sponsor/legal text and the parked engagement features are unchanged. No new setting, option or dependency.

Delivery evidence outside this Intent's executable acceptance: acceptance here is a source and hook check; no browser or server is available to it. The Build adds automated browser regression checks (Playwright, already a dev dependency under `assets/`) that exercise the behavior above through real clicks, modifier-clicks, keyboard and focus, and inspect the accessibility tree at desktop and 390px widths with touch and zoom. If the Build cannot run them, it reports that desktop/390px keyboard, focus, touch and zoom evidence remains an outstanding handoff; source checks alone do not close the issue.

## Decisions
- The scripted card click target is replaced by a native anchor because role="link" on a clickable div cannot honour modifier-click, middle-click or the context menu. (evidence: lib/elixir_drops_web/live/drops_list_helper.ex; lib/elixir_drops_web/live/drop_components.ex) (source: request)
- Copy actions, account, notification and search triggers become `<button>` elements with names and `aria-expanded` state, instead of clickable divs. (evidence: lib/elixir_drops_web/live/drop_components.ex) (source: request)
- Search suggestions use the listbox/option pattern with arrow-key selection handled in the existing hook; history delete shows on focus. (evidence: lib/elixir_drops_web/live/drop_components.ex; assets/js/hooks/search_suggestions.js) (source: request)
- No tooltip markup exists in lib or assets; the only hover-only reveal is the history-delete button, so tooltip help is satisfied by focus visibility and accessible names, and no tooltip component is added. (evidence: lib/elixir_drops_web/live/drop_components.ex) (assumption: the issue's tooltip item refers to these hover-only reveals, as no tooltip exists in source) (source: request)
- The modal already has role, aria-modal, focus_wrap, Escape and focus_first; its missing piece is JS.push_focus so pop_focus has something to return to. The three popups built on `show_popup`/`hide_popup` lack dialog semantics and receive them. (evidence: lib/elixir_drops_web/components/core_components.ex; lib/elixir_drops_web/live/drop_components.ex) (source: request)
- Clipboard feedback timing and success/error wiring stay as the completed copy Intent left them; only the live-region semantics are added. (evidence: assets/js/hooks/copy_to_clipboard.js) (source: request)
- Acceptance is whitespace-normalized source pattern checks because acceptance cannot start a browser or the server; the Build's Playwright regression tests carry the real-behavior proof. Controls are deferred. (evidence: .kogen/project.yaml; assets/package.json) (assumption: the linked issue was not readable in this session; scope derives from the request text and the interactive markup found in source) (source: request)
- Rendered desktop/390px baseline was unverified in the request; no rendered inspection is claimed by this Intent. (source: request)
- Replace the scripted card click target with a native visible anchor. (decision: D1, round 1) (evidence: lib/elixir_drops_web/live/drops_list_helper.ex; lib/elixir_drops_web/live/drop_components.ex) (assumption: The exact card-wide click mechanism is left to the Build.) (source: request)
- Copy actions and header triggers become named buttons with accurate aria-expanded. (decision: D2, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex) (assumption: Rendered behavior unverified.) (source: request)
- Search suggestions use listbox/option semantics with hook-driven arrow keys; history delete visible on focus. (decision: D3, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex; assets/js/hooks/search_suggestions.js) (assumption: Rendered behavior unverified.) (source: request)
- No tooltip component exists; hover-only reveals get focus availability. (decision: D4, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex) (assumption: Issue text not readable; tooltip item interpreted from source.) (source: request)
- Add push_focus to show_modal and dialog semantics to the three popups. (decision: D5, round 1) (evidence: lib/elixir_drops_web/components/core_components.ex; lib/elixir_drops_web/live/drop_components.ex) (assumption: Focus containment for popups verified only by the Build's browser tests.) (source: request)
- Clipboard feedback becomes a polite live region; success/error wiring unchanged. (decision: D6, round 1) (evidence: assets/js/hooks/copy_to_clipboard.js) (assumption: Announcement timing with the 500ms hide not browser-verified.) (source: request)
- Acceptance uses source pattern checks; controls deferred; Playwright tests required of the Build. (decision: D7, round 1) (evidence: .kogen/project.yaml; assets/package.json) (assumption: Patterns are structural proxies; rendered desktop/390px evidence remains a handoff.) (source: request)
- No rendered inspection is claimed. (decision: D8, round 1) (assumption: Rendered baseline unverified.) (source: request)

## Source comparison
- Semantic Drop links, modifier-click, context menu, keyboard, nested menu not navigating: addressed (source: request).
- Copy actions, account/notification/search triggers names and state: addressed (source: request).
- Suggestion keyboard selection and history-delete on focus: addressed (source: request).
- Tooltip help without hover: addressed as focus availability for the only hover-only reveal (source: request).
- Dialog semantics, initial focus, containment, Escape, focus return: addressed (source: request).
- Clipboard result feedback announced: addressed (source: request).
- Image alternatives: addressed (source: request).
- Comment authorization, OAuth redesign, parked engagement features, logo/tagline, broad redesign, sponsor/legal, push, deployment: omitted by request.
- Rendered desktop/390px, touch and zoom evidence: outstanding handoff, not closable by source checks.

## Tests
- Drop card is a native link and nested menu does not navigate: scenario "Drop cards use a visible native link instead of a scripted click target", plus a Playwright regression test of modifier-click, middle-click and nested menu actions (scenario)
- Copy actions are buttons, feedback is announced: scenario "Copy actions are real buttons and clipboard feedback is announced" (scenario)
- Triggers are named and report state: scenario "Account, notification and search triggers are named buttons that report their state" (scenario)
- Suggestion keyboard selection and focus-visible delete: scenario "Search suggestions support keyboard selection and history delete is reachable on focus" (scenario)
- Dialog semantics, Escape and focus return: scenario "Dialogs have semantics, Escape and focus return" (scenario)
- Image alternatives: scenario "Images have useful alternatives or explicit decorative alt" (scenario)
- Click-away close and author permissions preserved: scenario "Existing click-away close and author permissions are preserved" plus existing LiveView and feature tests under test/elixir_drops_web (existing)

## Feasibility
- none
