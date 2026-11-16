# UI design system

This document defines the shared type, spacing, control and color roles of
ElixirDrops. It keeps the retained identity: the masonry feed, the original
outlined logo, the white reading canvas, code-forward content and labelled
sponsor placements. It adds no theme, dark palette or framework. The styles live
in `assets/css/app.css` and the component markup in
`lib/elixir_drops_web/live/drop_components.ex`.

## Menu roles

Every menu (Drop card menu, Drop page menu, account slide menu, Markdown rows)
uses the same role classes instead of per-menu padding and color utilities.

| Role | Class | Definition |
| --- | --- | --- |
| Panel | `.menu-panel` | White surface, 1px `#d1d5db` border, 0.5rem radius, 0.5rem padding, `min-width` 12.5rem and never wider than the viewport minus 2rem. |
| Menu heading | `.menu-heading` | 0.875rem text in `#6b6b6b` (5.3:1 on white), 0.5rem horizontal padding. Headings label a group; they are not actions. |
| Menu row | `.menu-row` | The action: flex row, 0.5rem gap, 0.5rem padding, `min-height` 2.75rem (44px) so every row has the same action height, `#4f4f4f` text, hover and active `#5947F1` on a light surface. |
| Separator | `.menu-separator` | 1px `#e5e7eb` line with 0.25rem vertical margin, placed between groups (for example before "Edit drop"). It is decorative, so it carries no contrast target. |

Icons inside rows are 1.25rem (`h-5 w-5`) and inherit the row color; a trailing
external-link icon may be 1rem. Deliberate hierarchy is permitted: a menu may
use a larger heading or different spacing for one group when the hierarchy is
the point, as long as it composes these roles rather than ad hoc utilities.

### Placement

Menus are anchored to their content, not to fixed page offsets. The Drop card
menu and the Drop page menu live in a `relative` wrapper around their trigger
(`bottom-full` above the card trigger, `top-full` below the page trigger,
`right-0`). The Markdown help tooltip is anchored to the menu heading and spans
the menu width. The notification panel is anchored to the feed container at its
right edge. Fixed offsets such as `top-[7.5rem]` and `sm:right-[20%]` must not
return. At desktop, 390px and zoom, a menu must not clip, leave the viewport,
cover essential controls or create horizontal page overflow.

## Padding and margins

- Page and card padding: `.drop-content` 1.5rem; content grid inline padding 1rem
  (2rem from 768px).
- Menu panel padding 0.5rem; row padding 0.5rem; heading padding 0.5rem.
- Stack gaps use the Tailwind scale (0.25rem, 0.5rem, 0.75rem, 1rem, 1.5rem, 2rem).

## Type

- Sans: Roboto (`--font-roboto`), body `#4f4f4f` on the white canvas.
- Headings weight 500. The feed has one `<h1>` (visually hidden, "Latest Drops"),
  Drop cards and the comments heading are `<h2>`, and a Drop page has a single
  `<h1>` title, so levels never skip.
- Menu text is 0.875rem; card meta text is 0.75rem.

## Code typography and surface

Code is JetBrains Mono (`--font-jetBrains`). The Google Fonts import loads
weights 400, 500 and 700. `pre` and `code` inside `.drop-body`,
`.drop-full-content`, `.comment-body` and `.drop-preview` use it on the code
surface, the `--code-surface` custom property (`#21252b`, a step darker than the
`onedark` syntax theme's own `#282c34` background, which the `pre` rule overrides).
Highlighted token colors come from that theme; the theme's comment color
(`#5c6370`) is raised to `#9aa1ad` so every token keeps 4.5:1 on the surface. Do
not change the surface without re-checking them.

## Color roles

| Role | Value | Use |
| --- | --- | --- |
| Action | `#2F19EE` (`--color-blue_primary`) | Primary buttons, outlined buttons, the focus ring. 8.4:1 on white. |
| Reading link | `#5947F1` | Links inside Markdown content and hover color of menu rows. 5.8:1 on white. |
| Muted text | `#6b6b6b` | Meta text, headings, icons. 5.3:1 on white. |
| Body text | `#4f4f4f`, `#252525` | Text and titles. |

The action color and the reading link color are kept distinct and are not
flattened into one. Sponsor colors stay scoped to their labelled placements.

## Contrast targets

- Ordinary text: 4.5:1. Large text (18.66px bold or 24px): 3:1.
- Meaningful nontext (icons that carry meaning, input boundaries) and focus
  boundaries: 3:1.
- The targets apply in every actual state: default, hover, focus, active and
  disabled. Hover uses `hover:opacity-80` on action buttons and stays above 4.5:1;
  disabled controls keep their text and boundary at 3:1 or better.
- `#8e8e8e`, `#868686`, `#797979` and `text-gray-400` fail on white and must not be
  used for text or meaningful icons.

## Pointer and focus

- Actionable controls show `cursor-pointer` (a shared base rule covers links,
  enabled buttons, `summary`, `role="button"` and `role="option"`).
- One shared `:focus-visible` rule draws a 2px action-color outline with a 2px
  offset on links, buttons, inputs, selects, textareas and focusable elements.
  On dark surfaces (welcome banner, code copy bar, screenshot header) the outline
  is white. `.remove-outline` only removes the pointer-focus outline, never the
  keyboard focus indicator.

## Reduced motion

`@media (prefers-reduced-motion: reduce)` disables or minimizes transitions,
animations and smooth scrolling: the fade-in and hover travel of cards, the
`transition-opacity` menu fade, the screenshot progress transition and spinners.
The page-loading topbar is not shown, and the scroll-to-top action jumps instead
of scrolling smoothly.

## Error page

`error_html/404.html.heex` is a complete HTML document (error rendering has
`layout: false`) that links `/assets/css/app.css`, keeps the white canvas and type
system, has an `<h1>`, says the page was not found and links to the home page and
the archive. The response keeps HTTP 404. No `/privacy`, `/terms`, `/about` or
`/sponsor` page exists or is linked.

## Browser regression checks

`test/elixir_drops_web/features/ui_visual_test.exs` (Playwright through the
project's `phoenix_test_playwright` feature setup) opens the feed, a Drop page,
the card menu, account menu, notification panel, search suggestions and the 404
page at desktop (1280px), phone (390px) and zoom (320px, what a 400% browser zoom
leaves a 1280px window) widths, signed out and signed in, with keyboard focus and
reduced-motion emulation. It asserts no horizontal overflow, menus inside the
viewport, computed contrast against the targets above, JetBrains Mono and the
`--code-surface` on code, and HTTP 404, and writes a screenshot of each state to
`tmp/ui-visual/<git revision>/`. Run it with:

```sh
FEATURE_TESTS=true mix test test/elixir_drops_web/features/ui_visual_test.exs --only feature
```
