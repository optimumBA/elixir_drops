Feature: Public contributor profile page and its Drops tab
  This feature drives the real profile LiveView through two focused ExUnit files, one per scenario, against the local test database with small synthetic fixtures.

  Scenario: Public access, identity, privacy, tab links and default
    Then public-profile-page-and-drops-tab: the test file "profile_page_test.exs" runs its test "public profile page, identity, privacy, tabs and default" and it passes
    And public-profile-page-and-drops-tab: the profile pages of every viewer in "profile_page_test.exs" test "public profile page, identity, privacy, tabs and default" show no draft, email, token, search history or bookmark text

  Scenario: Drops tab and its four feed states
    Then public-profile-page-and-drops-tab: the test file "drops_tab_test.exs" runs its test "drops tab lists published drops and exposes the four feed states" and it passes
