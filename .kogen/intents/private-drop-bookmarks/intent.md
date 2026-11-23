# Add private account bookmarks for Drops

Slug: private-drop-bookmarks
Model: not applicable — a bookmark is one row per account and Drop; the behavior is verified through rendered pages, not a state machine
Acceptance:
- .kogen/intents/private-drop-bookmarks/acceptance.feature
- features/steps/private-drop-bookmarks__run.js
- features/steps/private-drop-bookmarks__driver/support.exs
- features/steps/private-drop-bookmarks__driver/state_test.exs
- features/steps/private-drop-bookmarks__driver/list_test.exs
- features/steps/private-drop-bookmarks__driver/bound_test.exs
- features/steps/private-drop-bookmarks__driver/privacy_test.exs
- features/steps/private-drop-bookmarks__driver/browser_test.exs

Signed-in users can save and remove a Drop with a Bookmark action: in the three-dot menu of every Drop card, and as a visible button beside Copy link on the individual Drop page. Every Drop list that renders cards (homepage, the My drops page, the public profile Drops tab, search results and the Bookmarks list) uses the same shared card behavior and shows the current saved state. A private Bookmarks list sits beside My drops, shows the most recently saved Drops first with infinite scroll and an empty state, and lets the user remove saved Drops. Signed-out visitors see the action wherever it is offered and are prompted to sign in when they select it; nothing is saved. Only the individual Drop page shows the aggregate bookmark count, publicly when above zero. Nobody can see who bookmarked a Drop or another account's bookmark list. This is a fresh build from the current approved baseline: the parked earlier implementation is historical and is not reused.

Observable contract used by the acceptance (chosen by the Shaper, see Decisions): every bookmark control is a `button` with a unique DOM id whose visible text or accessible name contains Bookmark and that carries the standard `aria-pressed` toggle state (`true` when saved, `false` when not, also for signed-out visitors); the acceptance finds it by that text and state, not by a custom attribute. Inside a Drop card the control sits in the card's three-dot `.menu-panel`; on the Drop page it is outside any menu, a sibling of the Copy link button. The aggregate count is the visible phrase `N bookmark` or `N bookmarks` (only on the Drop page, only when N is above zero). The Bookmarks page is reached from a link whose text is `Bookmarks` placed directly after the `My drops` link in the account menu (`#slide-menu`) and in the My drops header nav (`#secondary-nav-links`); it lists Drops as the shared `.drop-card` cards, continues on the existing `load_more` event, and its empty state contains the text `No bookmarks yet`. The signed-out prompt is the existing `#signin-popup-message` dialog with its Sign in with GitHub link. The four LiveView driver files run in one ExUnit invocation and the browser file in a second one, so the whole acceptance fits the time limit.

## Decisions
- A bookmark is a private row owned by one account for one Drop, unique per account and Drop, created with its save time; saving an already saved Drop or removing an unsaved one leaves the state unchanged; deleting a Drop or account removes its bookmarks. (decision: D1, round 1) (evidence: lib/elixir_drops/drops.ex; lib/elixir_drops/comments.ex; priv/repo/migrations/20250703134839_create_comments.exs) (assumption: cascade on Drop and account deletion is the Shaper's choice) (source: request)
- The Bookmark action is one shared behavior: the shared Drop card and the Drop page render the same control and one shared event handler toggles it, so the homepage, My drops, public profile Drops tab, search results, the Bookmarks list and the Drop page agree on saved state and a toggle on any of them is reflected on the others after reload. (decision: D2, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/drops_list_helper.ex; lib/elixir_drops_web/live/live_helpers.ex) (source: request)
- Entry points: the card's three-dot menu (drop_card_menu) gets the Bookmark item and the Drop page action row gets a visible button next to the existing Copy link button; the control text says Bookmark and its state is exposed through aria-pressed. (decision: D3, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex) (assumption: the label and aria-pressed state are the Shaper-chosen observable contract) (source: request)
- The private Bookmarks list is an authenticated page for the signed-in account only, linked as Bookmarks directly after My drops in the account menu and in the My drops header nav; it lists exactly that account's saved Drops as shared cards, ordered by save time descending (a re-saved Drop returns to the top, ties broken by a unique key), in batches loaded by the existing infinite-scroll `load_more` event, and shows an empty state with the text No bookmarks yet when nothing is saved. Removing from a card in the list drops it from the list. (decision: D4, round 1) (evidence: lib/elixir_drops_web/router.ex; lib/elixir_drops_web/live/user_drop_live/index.html.heex; lib/elixir_drops_web/live/live_helpers.ex) (assumption: the route is chosen by the Build; the acceptance finds it through the Bookmarks link) (source: request)
- Signed-out visitors see the same control (not saved) wherever it is offered; selecting it opens the existing sign-in dialog and saves nothing, so after signing in the Drop is still not saved. (decision: D5, round 1) (evidence: lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/drop_live/index.html.heex; lib/elixir_drops_web/live/drop_live/show.html.heex) (source: request)
- Only the individual Drop page shows the aggregate bookmark count, publicly for guests and signed-in users when above zero, reflecting saves and removals; no list, card, profile or Bookmarks page shows a count. (decision: D6, round 1) (source: request)
- Nobody can see who bookmarked a Drop or another account's bookmark list: no page, markup or route renders a Drop's bookmarkers (not the author, not other accounts, not guests), the public profile exposes no bookmarks, and the Bookmarks address of one account never shows another account's Drops and is not available to signed-out visitors. (decision: D7, round 1) (evidence: lib/elixir_drops_web/live/profile_live/show.ex; lib/elixir_drops_web/router.ex) (source: request)
- Work over the Bookmarks collection is bounded: opening the homepage with saved state, opening Bookmarks and every continuation batch cost no more repo queries for an account with three times as many bookmarks as a small one, and a batch never costs one query per entry. The acceptance takes the bound from the observed cost of the small account and states no fixed query number; the driver's sizes stay small so the whole acceptance fits its time limit. (decision: D8, round 1) (assumption: The request states no query-cost or scaling requirement and the decision carries no assumption marker; it adds scope.) (source: request)
- Controls are deferred: the change spans a migration, context, shared card and Drop page components, LiveViews, a new route and the sign-in prompt, so correct and wrong implementation overlays cannot be written honestly in the shaping budget; the Build writes the implementation and its own tests under test/. (decision: D9, round 1) (assumption: deferral of wrong-implementation controls is acceptable, as in earlier ElixirDrops intents) (source: request)
- The linked Room decision is honored: a fresh build on the current baseline; no parked code is reused. (decision: D10, round 1) (source: request)

## Source comparison
- Save/remove from homepage three-dot menu and Drop page button beside Copy link, saved state across pages, reload and second session: scenario 1, request check 1 and 2.
- Remove from Drop page, homepage, shared card lists and Bookmarks with state and membership agreeing: scenario 1, request check 2.
- Latest-saved-first, infinite scroll, empty state: scenario 2, request check 3.
- Signed-out sees action, sign-in prompt, nothing saved: scenario 5 (real browser), request check 4.
- Aggregate count only on Drop page when nonzero, reflects saves and removals, no identities; privacy from another account and guests: scenarios 1 and 4, request check 5.
- Collection work bound as bookmarks grow: scenario 3.
- Parked implementation: historical, not reused.

## Tests
- Save and remove agree across homepage, Drop page, My drops, public profile tab, Bookmarks and a second session; count reflects saves and removals: state_test.exs (scenario)
- Latest saved first, partial first batch, infinite scroll, re-save to top, empty state: list_test.exs (scenario)
- Query work for a small and a larger number of bookmarks stays within the same bound: bound_test.exs (integration)
- Privacy of lists and bookmarkers, count only on the Drop page: privacy_test.exs (scenario)
- Signed-out prompt and signed-in journey from homepage menu through Drop page and account menu to Bookmarks in a real browser: browser_test.exs (scenario)
- Build adds focused unit and LiveView tests under test/ for the bookmarks context and the shared control, and keeps existing card, comment and profile tests passing: test/elixir_drops, test/elixir_drops_web/live (integration)

## Feasibility
- none
