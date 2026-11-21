Feature: Public profile Comments feed
  This feature drives the real profile LiveView and a real browser through focused ExUnit files, each building its own fixtures in the local test database.

  Scenario: Feed isolation, batches, ties, states, deletion and totals
    Then public-profile-comments-tab-corrected: the test file "feed_test.exs" runs its test "comments feed lists only the contributor's comments and replies in tied-timestamp batches with every state" and it passes

  Scenario: A batch interrupted by switching tabs is never skipped or duplicated
    Then public-profile-comments-tab-corrected: the test file "interrupted_test.exs" runs its test "a batch interrupted by switching tabs is never skipped or duplicated" and it passes

  Scenario: Work per batch stays bounded for 15 and 100 entries
    Then public-profile-comments-tab-corrected: the test file "bound_test.exs" runs its test "query count per batch stays within the same bound for 15 and 100 entries" and it passes

  Scenario: Entry presentation
    Then public-profile-comments-tab-corrected: the test file "presentation_test.exs" runs its test "entries show drop link, date, markdown, code, reply context and an expand control" and it passes

  Scenario: Tab and Back continuity in a real browser
    Then public-profile-comments-tab-corrected: the browser test file "tabs_browser_test.exs" runs its test "both tabs keep entries and position across switching, an interrupted batch and Back" and it passes

  Scenario: View in discussion reaches the exact older comment in a real browser
    Then public-profile-comments-tab-corrected: the browser test file "discussion_browser_test.exs" runs its test "expand works from the keyboard and View in discussion reveals the exact older reply and comment" and it passes
