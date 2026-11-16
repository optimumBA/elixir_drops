Feature: Factual, consistent reader-facing copy
  This feature covers one corrective copy pass over ElixirDrops reader-facing text.
  Layout, routes, attribution and legal text are unchanged.

  Background:
    Given ui-copy-20261116: the ElixirDrops source checkout

  Scenario: Welcome message states what ElixirDrops is without superlatives
    Then ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "Welcome to ElixirDrops!"
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "ElixirDrops is a collection of short, practical Elixir, Phoenix and OTP tips. Sign in with GitHub to share your own Drops and join the discussion."
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "ultimate hub"
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "perfect place"
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "best tips and tricks"

  Scenario: Sign-in wording and Drop terminology are consistent in flash errors
    Then ui-copy-20261116: "lib/elixir_drops_web/user_auth.ex" contains the text "Sign in to access this page."
    And ui-copy-20261116: "lib/elixir_drops_web/user_auth.ex" does not contain the text "You must log in"
    And ui-copy-20261116: "lib/elixir_drops_web/live/user_drop_live/index.ex" contains the text "This Drop was not found, or you can only edit your own Drops."
    And ui-copy-20261116: "lib/elixir_drops_web/live/user_drop_live/index.ex" does not contain the text "You can only edit your own drops"

  Scenario: Failure messages explain what failed and what to do next
    Then ui-copy-20261116: "lib/elixir_drops_web/controllers/github_auth_controller.ex" contains the text "GitHub sign-in did not complete. Try signing in again."
    And ui-copy-20261116: "lib/elixir_drops_web/controllers/github_auth_controller.ex" does not contain the text "User authentication failed!"
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_live/show.ex" contains the text "Your comment was not saved. Try again."
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_live/show.ex" contains the text "Your changes were not saved. Try again."
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_live/show.ex" does not contain the text "Failed to add your comment"
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_live/show.ex" does not contain the text "Failed to update comment"

  Scenario: Connection notices state the connection state and do not claim a save succeeded or was lost
    Then ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Connection lost\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Reconnecting. If you just saved something, check that it saved before trying again.\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Server error\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Reconnecting to the server. If you just saved something, check that it saved before trying again.\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Success\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "gettext(\"Error\")"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" does not contain the text "We can't find the internet"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" does not contain the text "Hang in there"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" does not contain the text "Something went wrong!"
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "id=\"client-error\""
    And ui-copy-20261116: "lib/elixir_drops_web/components/layouts.ex" contains the text "id=\"server-error\""

  Scenario: Link copy confirmation appears only after the clipboard reports success
    Given ui-copy-20261116: the link-copy hook is mounted with a fake clipboard library
    When ui-copy-20261116: the visitor clicks the copy link
    Then ui-copy-20261116: the copy message is hidden
    When ui-copy-20261116: the clipboard library reports success
    Then ui-copy-20261116: the copy message is visible with the text "Link copied to clipboard"
    When ui-copy-20261116: the confirmation timers elapse
    Then ui-copy-20261116: the copy message is hidden

  Scenario: A failed copy says so instead of confirming
    Given ui-copy-20261116: the link-copy hook is mounted with a fake clipboard library
    When ui-copy-20261116: the visitor clicks the copy link
    And ui-copy-20261116: the clipboard library reports error
    Then ui-copy-20261116: the copy message is visible with the text "Copy failed. Select the link and copy it manually."
    When ui-copy-20261116: the confirmation timers elapse
    Then ui-copy-20261116: the copy message is hidden

  Scenario: Copy popup markup and code-block copy follow the same success-only rule
    Then ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" contains the text "id=\"copy-confirm-text\""
    And ui-copy-20261116: "lib/elixir_drops_web/live/drop_components.ex" does not contain the text "<span>copied to clipboard</span>"
    And ui-copy-20261116: "assets/js/hooks/drop_body.js" contains the text ".on('success'"
    And ui-copy-20261116: "assets/js/hooks/drop_body.js" does not contain the text "copyPrompt.addEventListener('click'"

  Scenario: Authentication and contribution routes are preserved
    Then ui-copy-20261116: "lib/elixir_drops_web/controllers/github_auth_controller.ex" contains the text "redirect(to: ~p\"/\")"
    And ui-copy-20261116: "lib/elixir_drops_web/user_auth.ex" contains the text "Phoenix.LiveView.redirect(to: ~p\"/\")"
    And ui-copy-20261116: "lib/elixir_drops_web/live/user_drop_live/form_component.html.heex" contains the text "Create Drop"
    And ui-copy-20261116: "lib/elixir_drops_web/live/user_drop_live/form_component.html.heex" contains the text "Update Drop"
