Feature: Private account bookmarks
  This feature drives the real LiveViews and a real browser through focused ExUnit files, each building its own fixtures in the local test database.

  Scenario: Saving and removing agree across every list, the Drop page and sessions
    Then private-drop-bookmarks: the test file "state_test.exs" runs its test "saving and removing agree across the homepage, Drop page, other lists, Bookmarks and sessions" and it passes

  Scenario: Bookmarks lists latest saved first, scrolls and shows an empty state
    Then private-drop-bookmarks: the test file "list_test.exs" runs its test "bookmarks list shows latest saved first, loads on scroll and shows an empty state" and it passes

  Scenario: Work stays bounded as the number of bookmarks grows
    Then private-drop-bookmarks: the test file "bound_test.exs" runs its test "query count stays within the same bound for a small and a large number of bookmarks" and it passes

  Scenario: Lists and bookmarkers stay private and the count shows only on the Drop page
    Then private-drop-bookmarks: the test file "privacy_test.exs" runs its test "bookmark lists and bookmarkers stay private and the count shows only on the Drop page" and it passes

  Scenario: Signed-out prompt and the signed-in bookmark journey in a real browser
    Then private-drop-bookmarks: the browser test file "browser_test.exs" runs its test "signed-out visitors are prompted to sign in and a signed-in visitor completes the bookmark journey" and it passes
