# Return 404 for unsupported sign-in providers

Slug: unsupported-oauth-providers-return-not-found
Model: not applicable — stateless routing rule: a path either matches a configured provider route or no route
Acceptance:
- .kogen/intents/unsupported-oauth-providers-return-not-found/acceptance.feature
- features/steps/unsupported-oauth-providers-return-not-found__run.js
- features/steps/unsupported-oauth-providers-return-not-found__driver/unsupported_providers_test.exs

For ElixirDrops Studio issue c61d314c-38b8-4c2e-ad77-d735e9dae355 (AppSignal incident 14, 231 occurrences): the `/auth` scope in `lib/elixir_drops_web/router.ex` declares catch-all `GET /auth/:provider` and `GET /auth/:provider/callback`. Ueberauth is configured for GitHub only (`config/config.exs`), so for any other provider segment the Ueberauth plug passes through and the controller raises: `GET /auth/login` and `/auth/google` raise `UndefinedFunctionError` (`GithubAuthController.request/2`), `/auth/google/callback` raises `Phoenix.ActionClauseError` (observed in a scratch test on 0bdfc4f). Both end as a 500.

The change: only providers configured under `config :ueberauth, Ueberauth, providers: [...]` get routes. The `/auth` scope generates `GET /auth/NAME` (action `:request`) and `GET /auth/NAME/callback` (action `:callback`) of `GithubAuthController` for each configured provider key, read from that same configuration at compile time, and keeps `GET /auth/logout`. The catch-all provider routes are removed, so every other provider segment on both paths matches no route and gets the application's normal rendered 404 page, with no exception. The router names no provider literally. GitHub initiate (including return-to storage), GitHub callback success and failure, every flash, redirect and session effect, and logout are unchanged. Out of scope: OAuth credentials, scopes, session handling, return-to behavior, user creation, any route outside the `/auth` scope, new dependencies, a second provider.

The controller test file `test/elixir_drops_web/controllers/github_auth_controller_test.exs` gains regressions in its existing style: `get` plus `html_response(conn, 404)` for the initiate and callback paths of `/auth/login`, `/auth/google` and `/auth/not-a-provider` (never `assert_error_sent`), `Phoenix.Router.route_info/4` returning `:error`, GitHub initiate redirecting to github.com while keeping `return_to` (the test sets `:ueberauth, Ueberauth.Strategy.Github.OAuth` client credentials in the test process environment and restores them, since the test environment has none), and the exact configured route set.

Acceptance runs a self-contained ExUnit file owned by this Intent, together with the existing controller test file, in one `mix test` invocation. No browser is started and no database write is needed for the 404 checks.

## Decisions
- Routes are generated in the `/auth` scope from the keys of the Ueberauth `providers` configuration read with `Application.compile_env(:ueberauth, Ueberauth)`; the logout route stays literal and declared first. (constraint: no provider name literal in the auth scope; no catch-all provider route remains) (evidence: lib/elixir_drops_web/router.ex; config/config.exs) (source: request)
- Unsupported providers are not dispatched at all (404 from the router's no-match handling) rather than rescued in the controller. (evidence: lib/elixir_drops_web/controllers/github_auth_controller.ex; lib/elixir_drops_web/controllers/error_html/404.html.heex) (source: request)
- The controller needs no change; `plug Ueberauth` and `store_return_to` stay as they are. (evidence: lib/elixir_drops_web/controllers/github_auth_controller.ex) (source: request)
- Acceptance runs the helper ExUnit file and the existing controller test file in one cached `mix test --trace` run and judges named tests from the trace output. (evidence: test/support/conn_case.ex; test/test_helper.exs; features/steps/authorize-comment-deletion-by-user-and-drop__run.js) (assumption: mix test accepts an explicit test file outside test/ and finishes within 120 s on the acceptance host; the helper was run to completion from a scratch directory in shaping) (source: request)

## Source comparison
- 404 for /auth/login, /auth/google, /auth/not-a-provider on initiate, no exception: scenario "Unsupported initiate paths answer 404" and "The router does not dispatch unsupported providers" (source: request).
- 404 for callback paths /auth/not-a-provider/callback and /auth/google/callback (today ActionClauseError): scenario "Unsupported callback paths answer 404" (source: request).
- GitHub initiate redirect and return_to preserved: scenario "GitHub initiate keeps its redirect and return-to" (source: request).
- Existing callback, flash and logout behavior unchanged: scenarios "GitHub callback failure keeps its redirect and flash" and "The existing controller tests pass unchanged" (source: request).
- Provider derived from Ueberauth configuration, exact route set, no literal in router: scenario "The auth routes come from the Ueberauth configuration" (source: request).
- Credentials, scopes, session, return-to, user creation, other routes, dependencies, signed landing and deployment: unchanged or outside acceptance (source: request).

## Tests
- Unsupported providers return 404 on initiate and callback without raising and are not dispatched: regressions in test/elixir_drops_web/controllers/github_auth_controller_test.exs using get, html_response(conn, 404) and Phoenix.Router.route_info/4 (regression)
- GitHub initiate redirect and return-to are unchanged: test in the same file (integration)
- Auth routes equal the configured providers plus logout, router names no provider: test in the same file (integration)
- Existing callback and logout behavior: existing tests in the same file unchanged (existing)

## Feasibility
- none
