Feature: Public profile GitHub link opens in a new tab
  This feature makes the View on GitHub link on the public profile open natively in a new tab while internal navigation stays unchanged.

  Scenario: The rendered GitHub link has new-tab attributes for a guest and a signed-in other user
    Then profile-github-opens-new-tab: the single View on GitHub anchor of the viewed contributor has target _blank, rel with noopener and noreferrer, the contributor's own GitHub URL, the same label and no script handler, in file "rendered_test.exs" test "GitHub link is a native new-tab link for guest and signed-in viewer"

  Scenario: Activating the GitHub link in a real browser opens exactly one new tab
    Then profile-github-opens-new-tab: activating View on GitHub opens exactly one new browsing context at the contributor's GitHub URL while the original profile page keeps its URL and content, in file "browser_test.exs" test "activating View on GitHub opens one new context and leaves the profile tab unchanged"

  Scenario: Internal navigation links are unchanged
    Then profile-github-opens-new-tab: every non-GitHub link on the profile keeps its href and has no target, for a guest and a signed-in user, in file "internal_links_test.exs" test "internal and navigation links keep href and have no target"
