Feature: Only configured sign-in providers are routed
  This feature runs the real router and controller through isolated tests and the existing controller tests.

  Scenario: Unsupported initiate paths answer 404
    Then unsupported-oauth-providers-return-not-found: the isolated regression "unsupported initiate paths answer 404 without raising" passes

  Scenario: Unsupported callback paths answer 404
    Then unsupported-oauth-providers-return-not-found: the isolated regression "unsupported callback paths answer 404 without raising" passes

  Scenario: The router does not dispatch unsupported providers
    Then unsupported-oauth-providers-return-not-found: the isolated regression "the router does not dispatch unsupported providers" passes

  Scenario: GitHub initiate keeps its redirect and return-to
    Then unsupported-oauth-providers-return-not-found: the isolated regression "GitHub initiate redirects to github.com and keeps return_to" passes

  Scenario: GitHub callback failure keeps its redirect and flash
    Then unsupported-oauth-providers-return-not-found: the isolated regression "GitHub callback failure keeps its redirect and flash" passes

  Scenario: The existing controller tests pass unchanged
    Then unsupported-oauth-providers-return-not-found: the existing GitHub auth controller tests pass

  Scenario: The auth routes come from the Ueberauth configuration
    Then unsupported-oauth-providers-return-not-found: the isolated regression "the auth routes come from the Ueberauth configuration" passes
