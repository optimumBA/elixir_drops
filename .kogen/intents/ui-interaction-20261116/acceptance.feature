Feature: Native navigation and accessible controls
  This feature covers the shared interaction and accessibility repair of Drop cards, copy actions, header triggers, search suggestions, dialogs, clipboard feedback and images.
  Authorization, sign-in flows, click-away close and author permissions are unchanged.

  Background:
    Given ui-interaction-20261116: the ElixirDrops source checkout

  Scenario: Drop cards use a visible native link instead of a scripted click target
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drops_list_helper.ex" does not match the pattern 'role=\{match\?\(%Drop\{\}'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drops_list_helper.ex" does not match the pattern 'phx-click=\{match\?\(%Drop\{\}, item\) && JS\.navigate'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<a href=\{~p"/d/#\{@drop\.short_id\}"\} class="hidden"></a>'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<h3 class="drop-title"> ?<(a|\.link) (href|navigate)=\{~p"/d/#\{@drop\.short_id\}"\}'

  Scenario: Copy actions are real buttons and clipboard feedback is announced
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<div(?=[^<]*phx-hook="CopyToClipboard")'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*phx-hook="CopyToClipboard")(?=[^<]*type="button")'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<[a-z]+(?=[^<]*id="copy-confirm-message")(?=[^<]*role="status")(?=[^<]*aria-live="polite")'
    And ui-interaction-20261116: "assets/js/hooks/copy_to_clipboard.js" contains the text "clipboard.on('success'"
    And ui-interaction-20261116: "assets/js/hooks/copy_to_clipboard.js" contains the text "clipboard.on('error'"

  Scenario: Account, notification and search triggers are named buttons that report their state
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<(div|span|section)(?=[^<]*phx-click=\{JS\.toggle\(to: "#notifications-container"\))'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<(div|span)(?=[^<]*phx-click=\{JS\.toggle_class\("hidden", to: "#slide-menu"\))'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*notifications-container)(?=[^<]*aria-label=)(?=[^<]*aria-expanded=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*#slide-menu)(?=[^<]*aria-label=)(?=[^<]*aria-expanded=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*#search-overlay)(?=[^<]*aria-label=)(?=[^<]*aria-expanded=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*drop-card-menu-btn-)(?=[^<]*aria-expanded=)(?=[^<]*aria-controls=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*action-row-menu-btn-)(?=[^<]*aria-expanded=)(?=[^<]*aria-controls=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<button(?![^<]*aria-label=)[^<]*>\s*<(\.icon|Icons\.[a-z_]+) [^>]*/>\s*</button>'

  Scenario: Search suggestions support keyboard selection and history delete is reachable on focus
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern 'role="listbox"'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern 'role="option"'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<div :for=\{suggestion <- @[a-z_]+\}[^<]*tabindex="0"'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern 'opacity-0 group-hover:opacity-100(?![^"]*focus)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<button(?![^<]*aria-label=)[^<]*delete_(navbar_)?search_history'
    And ui-interaction-20261116: "assets/js/hooks/search_suggestions.js" contains the text "ArrowDown"
    And ui-interaction-20261116: "assets/js/hooks/search_suggestions.js" contains the text "ArrowUp"

  Scenario: Dialogs have semantics, Escape and focus return
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<[a-z]+(?=[^<]*id="signin-popup-message")(?=[^<]*role="(alert)?dialog")(?=[^<]*aria-modal="true")(?=[^<]*aria-labelledby=)(?=[^<]*phx-key="escape")'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<[a-z]+(?=[^<]*id="edit-form-cancel-confirm")(?=[^<]*role="(alert)?dialog")(?=[^<]*aria-modal="true")(?=[^<]*aria-labelledby=)(?=[^<]*phx-key="escape")'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<[a-z]+(?=[^<]*id=\{@id\})(?=[^<]*phx-hook="ScreenshotProgress")(?=[^<]*role="(alert)?dialog")(?=[^<]*aria-modal="true")(?=[^<]*aria-label)(?=[^<]*phx-key="escape")'
    And ui-interaction-20261116: "lib/elixir_drops_web/components/core_components.ex" matches the pattern 'def show_modal\(.*?\) when is_binary\(id\) do js \|> JS\.push_focus\(\)'
    And ui-interaction-20261116: "lib/elixir_drops_web/components/core_components.ex" contains the text "JS.pop_focus()"

  Scenario: Images have useful alternatives or explicit decorative alt
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<img(?![^<]*alt=)'
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "alt=\"notification icon\""
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not match the pattern '<img src=\{@drop\.user\.avatar\} alt=\{@drop\.user\.github_username\}'

  Scenario: Existing click-away close and author permissions are preserved
    Then ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "phx-click-away={JS.hide(to: \"#drop-card-menu-#{@id}\")}"
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text ":if={@author?}"
    And ui-interaction-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "phx-click-away={hide_popup(\"signin-popup-message\")}"
