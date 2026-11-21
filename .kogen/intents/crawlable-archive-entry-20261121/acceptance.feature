Feature: Crawlable archive entry on the public homepage
  This feature drives the real homepage and archive through two focused ExUnit files against the local test database with small synthetic fixtures; every request is a plain HTTP or LiveView render, so no JavaScript runs.

  Scenario: Homepage links to the archive from its body
    Then crawlable-archive-entry-20261121: the homepage initial HTML has one visible ordinary "Browse all Drops" link to the archive in the body and none in the header

  Scenario: An older article is reachable from the homepage link
    Then crawlable-archive-entry-20261121: the archive link from the homepage reaches an older Drop article without JavaScript and the feed, archive and article routes still work
