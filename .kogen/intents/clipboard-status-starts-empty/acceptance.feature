Feature: Clipboard status starts empty and follows the real copy result
  This feature covers the polite live status that reports the result of a copy action. Before any copy result the status holds no success or failure text, and after a real clipboard result it reports exactly that result.

  Background:
    Given clipboard-status-starts-empty: the copy status markup and link-copy hook are loaded with a fake clipboard library

  Scenario: The live status keeps its accessible semantics
    Then clipboard-status-starts-empty: the status is a polite live region that is not hidden from assistive technology
    And clipboard-status-starts-empty: the status is visually hidden

  Scenario: The live status text is rendered empty before any copy
    Then clipboard-status-starts-empty: the status text is empty
    And clipboard-status-starts-empty: the status text makes no success or failure claim

  Scenario: Activating the copy button alone claims nothing
    When clipboard-status-starts-empty: the visitor clicks the copy button
    Then clipboard-status-starts-empty: the status text is empty
    And clipboard-status-starts-empty: the status is visually hidden

  Scenario: A real clipboard success is reported and then returns to empty
    When clipboard-status-starts-empty: the visitor clicks the copy button
    And clipboard-status-starts-empty: the clipboard library reports success
    Then clipboard-status-starts-empty: the status text is "Link copied to clipboard"
    And clipboard-status-starts-empty: the status is visually shown
    When clipboard-status-starts-empty: the confirmation timers elapse
    Then clipboard-status-starts-empty: the status is visually hidden
    And clipboard-status-starts-empty: the status text is empty

  Scenario: A real clipboard error is reported as a failure and then returns to empty
    When clipboard-status-starts-empty: the visitor clicks the copy button
    And clipboard-status-starts-empty: the clipboard library reports error
    Then clipboard-status-starts-empty: the status text is "Copy failed. Select the link and copy it manually."
    And clipboard-status-starts-empty: the status text does not contain "Link copied"
    And clipboard-status-starts-empty: the status is visually shown
    When clipboard-status-starts-empty: the confirmation timers elapse
    Then clipboard-status-starts-empty: the status is visually hidden
    And clipboard-status-starts-empty: the status text is empty

  Scenario: A prior success is not reused for a later failed copy
    When clipboard-status-starts-empty: the visitor clicks the copy button
    And clipboard-status-starts-empty: the clipboard library reports success
    And clipboard-status-starts-empty: the clipboard library reports error
    Then clipboard-status-starts-empty: the status text is "Copy failed. Select the link and copy it manually."
    And clipboard-status-starts-empty: the status text does not contain "Link copied"
    When clipboard-status-starts-empty: the confirmation timers elapse
    And clipboard-status-starts-empty: the visitor clicks the copy button
    And clipboard-status-starts-empty: the clipboard library reports error
    Then clipboard-status-starts-empty: the status text is "Copy failed. Select the link and copy it manually."
    And clipboard-status-starts-empty: the status text does not contain "Link copied"

  Scenario: Delivered copy-button and hook wiring are preserved
    Then clipboard-status-starts-empty: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<button(?=[^<]*phx-hook="CopyToClipboard")(?=[^<]*type="button")'
    And clipboard-status-starts-empty: "lib/elixir_drops_web/live/drop_components.ex" matches the pattern '<[a-z]+(?=[^<]*id="copy-confirm-message")(?=[^<]*role="status")(?=[^<]*aria-live="polite")'
    And clipboard-status-starts-empty: "assets/js/hooks/copy_to_clipboard.js" contains the text "clipboard.on('success'"
    And clipboard-status-starts-empty: "assets/js/hooks/copy_to_clipboard.js" contains the text "clipboard.on('error'"
