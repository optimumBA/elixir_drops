# Align shared UI styling with retained identity

Slug: ui-visual-20261116
Model: not applicable — this is a styling, markup and documentation change of stateless presentation with no interacting domain state.
Acceptance:
- .kogen/intents/ui-visual-20261116/acceptance.feature
- features/steps/ui-visual-20261116__source.js

Shared UI gets one coherent, documented type, spacing and control system grounded in the retained ElixirDrops identity, while masonry, the original outlined logo, the white reading canvas, code-forward content and labelled sponsor placements stay as they are.

Required outcome (the Build is held to all of it):
- Document the system in `docs/ui-design-system.md` (linked from README.md operations documentation): roles for menu headings, menu rows, action height, icons, separators, padding and margins (deliberate hierarchy is permitted), the color roles (action `#2F19EE` as `--color-blue_primary`, reading link `#5947F1`, kept distinct and not flattened), the contrast targets (ordinary text 4.5:1, large text 3:1, meaningful nontext and focus boundaries 3:1 in every actual state: default, hover, focus, active, disabled), the JetBrains Mono code typography and the `--code-surface` token, and reduced motion.
- In `assets/css/app.css`, add shared role classes `.menu-heading`, `.menu-row` (with a `min-height` so rows have a consistent action height) and `.menu-separator`, and use them in the drop card menu, the account slide menu, the markdown menu and the other menus of `drop_components.ex` instead of per-menu ad hoc padding and color utilities.
- Menus, help and popups use content-anchored placement: the fixed offsets `top-[7.5rem]`, `top-[8.5rem]` and `sm:right-[20%]` are replaced by placement relative to their trigger or container, so at desktop, 390px and zoom they do not clip, leave the viewport, cover essential controls or create horizontal page overflow.
- Low-contrast text colors `#8e8e8e` and `#868686` on white are replaced by colors that reach 4.5:1 (for example `#6b6b6b` or darker); other text, link, icon, border and focus colors are audited in all states and corrected where they fall below the targets.
- Relevant controls have a clear pointer affordance (`cursor-pointer` on actionable controls) and a visible `:focus-visible` indicator in a shared rule; `.remove-outline:focus` no longer removes the outline without a visible replacement.
- `@media (prefers-reduced-motion: reduce)` disables or minimizes transitions, animations and smooth scrolling (including `transition-opacity`, the progress transition and topbar).
- Code and preview typography: `pre` and `code` in `.drop-body`, `.drop-full-content`, `.comment-body` and `.drop-preview` use JetBrains Mono on the documented code surface (`--code-surface` custom property in `app.css`, used by those `pre` rules); the Google Fonts import loads weight 400 (and optionally 500/700) of JetBrains Mono, not only 100 and 400, so code stays readable; syntax highlighting colors remain readable on the surface.
- Heading hierarchy: the feed page has an `<h1>` (it may be visually restrained or screen-reader only) in `drop_live/index.html.heex`; Drop card titles become `<h2 class="drop-title">` (the sponsor card too) so the feed goes h1, h2 without skipping levels; the comments heading becomes `<h2>`; the Drop page keeps its single `<h1>` title.
- 404: add `lib/elixir_drops_web/controllers/error_html/404.html.heex`, a complete HTML document (error rendering has `layout: false`) that links `/assets/css/app.css`, uses the white canvas and type system, has an `<h1>`, states that the page was not found and offers recovery links (home `/` and the archive). Enable it with `embed_templates "error_html/*"` in `error_html.ex`; the response retains HTTP404 (status 404), and the 500 and JSON error views are unchanged. Update `test/elixir_drops_web/controllers/error_html_test.exs` for the new 404 body and assert the 404 status of an unknown path. Do not add `/privacy`, `/terms`, `/about` or `/sponsor` routes or content.

Boundaries: masonry (`assets/css/components/masonry.css`), the logo and tagline, authorization, comments code, sponsor marks and colors (kept scoped to their placements, with sponsor labels unchanged), the Flat/Refined variants, a new dark palette, a wholesale redesign, new frameworks, parked features, deployment and public settings are untouched. No new setting, option or dependency.

Delivery evidence outside this Intent's executable acceptance: acceptance here is a source and documentation check; no browser or server is available to it. The Build adds automated browser regression checks (Playwright, already a dev dependency under `assets/`) that, at desktop and 390px widths, with zoom, keyboard focus and reduced-motion emulation, and in signed-out and authenticated states, open the feed, a Drop detail, the card menu, account menu, notification panel, search suggestions and the 404 page; assert no horizontal overflow, menus within the viewport, computed contrast against the targets, JetBrains Mono computed on code, and HTTP404; and keep screenshots with the current source revision. If the Build cannot run them, it reports that rendered desktop/390px, keyboard/focus, touch and zoom evidence (the baseline is unverified) remains an outstanding handoff; source checks alone do not close the issue.

## Decisions
- Acceptance is whitespace-normalized source and document pattern checks, because acceptance cannot start a browser or the server; the rendered proof is the Build's Playwright checks, and controls are deferred. (evidence: .kogen/project.yaml; assets/package.json; features/steps/README.md) (assumption: the linked issue was not readable in this session; scope derives from the request text and the source) (source: request)
- Shared menu roles are CSS classes `.menu-heading`, `.menu-row`, `.menu-separator` in the existing stylesheet, replacing ad hoc utilities such as the `text-[#8e8e8e]` heading; the current menus show the inconsistency. (evidence: assets/css/app.css; lib/elixir_drops_web/live/drop_components.ex) (source: request)
- `text-[#8e8e8e]` and `text-[#868686]` on white are below 4.5:1 and are replaced; the action color `--color-blue_primary: #2f19ee` and reading link `#5947F1` stay distinct. (evidence: assets/css/app.css; lib/elixir_drops_web/live/drop_components.ex) (source: request)
- No `prefers-reduced-motion` rule and no `:focus-visible` rule exist today, and `.remove-outline:focus` removes the outline, so shared rules are added. (evidence: assets/css/app.css; lib/elixir_drops_web/components/custom_input_components.ex) (source: request)
- Menus use fixed offsets (`top-[7.5rem]`, `top-[8.5rem]`) that are replaced with trigger-relative placement. (evidence: lib/elixir_drops_web/live/drop_components.ex) (source: request)
- The code font token already exists as `--font-jetBrains`, but the font import loads only weights 100 and 400 and only `.drop-image code` uses the font; preview and body code adopt it on a `--code-surface` token. (evidence: assets/css/app.css) (source: request)
- The feed has no `<h1>`, cards are `<h3>` and the welcome banner is a dismissible `<h2>`; the feed gets an h1 and cards become h2. (evidence: lib/elixir_drops_web/live/drop_components.ex; lib/elixir_drops_web/live/drop_live/index.html.heex; lib/elixir_drops_web/live/comment_components.ex) (source: request)
- The 404 view is a standalone template because errors render with `layout: false` and the default view returns plain text; the existing error test expecting the plain "Not Found" body is updated, and HTTP404 is retained. (evidence: config/config.exs; lib/elixir_drops_web/controllers/error_html.ex; test/elixir_drops_web/controllers/error_html_test.exs) (source: request)
- Absent conventional paths are not given content: the router has no privacy, terms, about or sponsor route and none is added. (evidence: lib/elixir_drops_web/router.ex) (source: request)
- Rendered desktop/390px baseline was unverified in the request; no rendered inspection is claimed by this Intent. (source: request)
- Share the menu, contrast, focus, motion, code, heading and 404 work in one Intent because they all edit the same shared stylesheet and component module; the final visual qualification follows the already-completed interaction and copy Intents. (decision: D1, round 1) (evidence: assets/css/app.css; .kogen/intents/ui-interaction-20261116/intent.md) (assumption: one Build is acceptable for this size; split if the Build shows independent failures.) (source: request)

## Source comparison
- Consistent menu, action, icon, separator, padding and margin roles, documented: addressed (source: request).
- Pointer and focus affordances, contrast targets, role-based action and link colors: addressed in source; computed contrast in all states is the Build's browser check (source: request).
- JetBrains Mono code typography and documented code surface: addressed (source: request).
- Menus/help without clipping, overflow or fixed offsets; zoom: addressed in source, rendered proof is a handoff if unrunnable (source: request).
- Reduced motion: addressed (source: request).
- h1/heading hierarchy and 404 recovery view retaining HTTP404; no invented /privacy, /terms, /about, /sponsor: addressed (source: request).
- Masonry, outlined logo, white canvas, sponsor placements: preserved, checked in acceptance (source: request).
- Flat/Refined, new tagline, dark palette, wholesale redesign, new framework, parked features, deployment, public settings, delivery, push, authorization issue: omitted by request.
- Rendered baseline, desktop/390px, keyboard/focus/touch/zoom, screenshots with source revision: outstanding handoff, not closable by source checks.

## Tests
- Design system roles, colors, contrast and code surface are documented: scenario "The design system roles and tokens are documented" (scenario)
- Menus share role classes and an action height: scenario "Menus and rows use shared role classes with a defined action height" (scenario)
- Menus are content-anchored and no horizontal overflow at desktop, 390px and zoom: scenario "Menus are anchored to their content instead of fixed offsets" plus a Playwright overflow and viewport test (scenario)
- Text contrast: scenario "Text colors reach the required contrast on the white canvas" plus a Playwright computed-contrast test (scenario)
- Focus and reduced motion: scenario "Controls have visible keyboard focus and reduced motion is honoured" plus a Playwright reduced-motion test (scenario)
- Code typography and surface: scenario "Code and preview typography uses JetBrains Mono on a documented code surface" (scenario)
- Heading hierarchy: scenario "Pages have a sensible heading hierarchy" (scenario)
- 404 view with HTTP404 and no invented routes: scenario "A site-consistent 404 page keeps HTTP 404 and invents no absent routes" and the updated ErrorHTMLTest and a 404 status assertion (regression)
- Identity and sponsor preservation: scenario "Preserved identity and sponsor placements are unchanged" plus existing tests under test/elixir_drops_web (existing)

## Feasibility
- none
