Feature: Shared UI styling aligned with the retained identity
  This feature covers the shared type, spacing, control, contrast, code-surface, motion, heading and 404 styling of ElixirDrops.
  Masonry, the original outlined logo, the white reading canvas, code-forward content, labelled sponsor placements, authorization and routes are unchanged.

  Background:
    Given ui-visual-20261116: the ElixirDrops source checkout

  Scenario: The design system roles and tokens are documented
    Then ui-visual-20261116: "docs/ui-design-system.md" exists
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '[Mm]enu heading'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '[Mm]enu row'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '[Ss]eparator'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '[Cc]ode surface'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '[Rr]educed motion'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern 'JetBrains Mono'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '#2[Ff]19[Ee][Ee]'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '#5947[Ff]1'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '4\.5:1'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '3:1'

  Scenario: Menus and rows use shared role classes with a defined action height
    Then ui-visual-20261116: "assets/css/app.css" matches the pattern '\.menu-heading \{'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern '\.menu-row \{[^}]*min-height:'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern '\.menu-separator \{'
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern 'class="[^"]*menu-heading'
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern 'class="[^"]*menu-row'
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern 'menu-separator'

  Scenario: Menus are anchored to their content instead of fixed offsets
    Then ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "top-[7.5rem]"
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "top-[8.5rem]"
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern 'sm:right-\[20%\]'

  Scenario: Text colors reach the required contrast on the white canvas
    Then ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern 'text-\[#(8[Ee]8[Ee]8[Ee]|868686)\]'

  Scenario: Action and reading link colors stay distinct and role-based
    Then ui-visual-20261116: "assets/css/app.css" matches the pattern '--color-blue_primary: #2[Ff]19[Ee][Ee]'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern 'text-\[#5947[Ff]1\] underline'

  Scenario: Controls have visible keyboard focus and reduced motion is honoured
    Then ui-visual-20261116: "assets/css/app.css" matches the pattern ':focus-visible'
    And ui-visual-20261116: "assets/css/app.css" does not match the pattern '\.remove-outline:focus \{ outline-style: none;'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern '@media \(prefers-reduced-motion: reduce\)'

  Scenario: Code and preview typography uses JetBrains Mono on a documented code surface
    Then ui-visual-20261116: "assets/css/app.css" matches the pattern 'JetBrains\+Mono:wght@(?!100)'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern '--code-surface:'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern '\.drop-preview pre[^{]*\{[^}]*font-family: var\(--font-jetBrains\)|font-jetBrains[^}]*\}[^{]*\.drop-preview|\.drop-preview (pre|code)[^{]*\{[^}]*font-jetBrains'
    And ui-visual-20261116: "assets/css/app.css" matches the pattern 'var\(--code-surface\)'
    And ui-visual-20261116: "docs/ui-design-system.md" matches the pattern '--code-surface'

  Scenario: Pages have a sensible heading hierarchy
    Then ui-visual-20261116: "lib/elixir_drops_web/live/drop_live/index.html.heex" matches the pattern '<h1'
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<h3 class="drop-title"'
    And ui-visual-20261116: "lib/elixir_drops_web/live/comment_components.ex" does not match the pattern '<h3 class="text-lg font-semibold mb-6'

  Scenario: A site-consistent 404 page is provided
    Then ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html/404.html.heex" exists
    And ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html/404.html.heex" matches the pattern '<h1'
    And ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html/404.html.heex" matches the pattern 'href="/"|href=\{~p"/"\}'
    And ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html/404.html.heex" matches the pattern 'assets/css/app\.css'
    And ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html.ex" matches the pattern '(^|[^#]) embed_templates "error_html/\*"'

  Scenario: Unknown paths still render through the HTML error view that carries HTTP 404
    Then ui-visual-20261116: "config/config.exs" contains the text "formats: [html: ElixirDropsWeb.ErrorHTML, json: ElixirDropsWeb.ErrorJSON]"
    And ui-visual-20261116: "lib/elixir_drops_web/router.ex" does not match the pattern '"/\*[a-z_]*"'
    And ui-visual-20261116: "lib/elixir_drops_web/controllers/error_html.ex" does not match the pattern 'put_status|send_resp\(.*200'

  Scenario: Absent conventional routes stay absent
    Then ui-visual-20261116: "lib/elixir_drops_web/router.ex" does not match the pattern '"/(privacy|terms|about|sponsor)"'

  Scenario: Preserved identity and sponsor placements are unchanged
    Then ui-visual-20261116: "assets/css/app.css" contains the text "@import './components/masonry.css';"
    And ui-visual-20261116: "priv/static/images/logo.png" exists
    And ui-visual-20261116: "lib/elixir_drops_web/components/layouts/root.html.heex" contains the text "bg-white"
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "Sponsored by DNSimple"
    And ui-visual-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "DNSimple · Sponsor"
