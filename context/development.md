# Development

## Tech Stack

- **Runtime**: Elixir ~> 1.15 (tracked via `mise`), Erlang/OTP, Node (for prettier and Playwright).
- **Web**: Phoenix ~> 1.8, Phoenix LiveView ~> 1.1, Bandit, phoenix_ecto, Ecto SQL ~> 3.13 on PostgreSQL.
- **Background jobs**: Oban ~> 2.18 with `Oban.Engines.Basic`.
- **Frontend**: Tailwind ~> 0.3 (Tailwind CSS 4.1.7), esbuild ~> 0.10, Heroicons, `masonry-layout`, `imagesloaded`.
- **Infra**: FLAME ~> 0.5 (Fly.io backend for screenshots), AppSignal, AWS S3 / Tigris.
- **Markdown/code**: `mdex`, `autumn` (syntax highlighting).
- **Dev tools**: `tidewave` (MCP proxy), `igniter`, `doctest_formatter`, `ex_doc`, `github_workflows_generator`.
- **Testing**: ExUnit, ExCoveralls, ExMachina, Faker, Mox, Wallaby (custom fork `almirsarajcic/wallaby#releases`), PhoenixTest.Playwright ~> 0.7, phoenix_live_reload.

## Setup

1. `mise install` (installs Elixir, Erlang, Node).
2. Install Tidewave MCP Proxy from `https://elixirdrops.net/d/UAo4BtYi`.
3. Start PostgreSQL.
4. Copy `.env.sample` -> `.env` and fill secrets.
5. `mix setup` — runs `deps.get`, installs prettier, `ecto.setup`, `assets.setup`, installs Playwright Chromium, builds assets.
6. `mix phx.server` — listens on `http://localhost:4000`.

## CI

Local gate: `make ci`

1. `MIX_ENV=test mix compile --warnings-as-errors`
2. `mix ci` alias: `deps.unlock --check-unused` -> `deps.audit` -> `cmd mix hex.audit` -> `sobelow --config .sobelow-conf --compact --quiet` -> `format --check-formatted` -> `cmd npx prettier -c .` -> `credo --strict --format oneline` -> `dialyzer --quiet-with-result` -> `test --cover --warnings-as-errors`
3. `MIX_ENV=test mix ecto.rollback --all --quiet`

**hex.audit form**: `cmd mix hex.audit` wraps the audit task as a fresh OS-level mix invocation so its non-zero exit reliably aborts the alias chain. Bare `hex.audit` resolves the task in the alias-runner env; wrapping forces a proper exit-code abort.

No dialyzer plt cache on disk for this repo — `plt_file` is `priv/plts/dialyzer.plt`.

**Asset freshness in tests**: `endpoint.ex` uses `gzip: Application.compile_env(:elixir_drops, :serve_gzip_assets, true)` (prod default true). Test and dev override to `false` in their config files (`config/test.exs:77-81`, `config/dev.exs:111`). When `gzip: true`, Plug.Static serves `priv/static/assets/js/app.js.gz` (if present) in preference to the plain `app.js`. Only `phx.digest` (in `assets.deploy`) regenerates `.gz`; bare `mix assets.build` only regenerates the plain file. A stale `.gz` from a prior branch can shadow source edits, causing feature tests to load old (possibly broken) JS while the source has been fixed. Result: test sees stale behavior, development work appears ineffective. Fix: (1) `mix.exs` `test` alias includes `assets.build` to keep plain `.js` current; (2) `gzip: false` in test env so only the fresh plain file is served. Pre-existing broken test runs may have a stale `.gz` on disk — `mix assets.build` clears the shadow by regenerating the plain file correctly.

## Test Commands

- `mix test` — unit + integration (Ecto sandbox, no server).
- `mix coveralls` / `mix coveralls.html` — coverage report.
- `mix test.features` — browser tests: deploys assets (`phx.digest` regenerates `.gz` fresh) then `FEATURE_TESTS=true mix test --only feature`.
- Playwright env vars: `PW_HEADLESS`, `PW_SCREENSHOT`, `PW_TIMEOUT` (default 500ms, affects Frame.evaluate timeouts), `PW_TRACE`.
- `PORT_TEST` overrides the feature-test port (default 4100).
- `@moduletag :feature` tests are EXCLUDED from `mix test` (via `test_helper.exs` `exclude: [:feature]`) and NOT run by `make ci`. They run only via `make test.features` or explicit `--include feature`. The masonry feature test is in this category.

## Environment Variables

| Variable                                                                                         | Purpose                          |
| ------------------------------------------------------------------------------------------------ | -------------------------------- |
| `DATABASE_URL`, `POOL_SIZE`, `ECTO_IPV6`                                                         | Prod DB connection               |
| `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`, `PHX_SERVER`                                              | Phoenix endpoint                 |
| `DNS_CLUSTER_QUERY`                                                                              | `DNSCluster` discovery           |
| `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`                                                       | GitHub OAuth                     |
| `APPSIGNAL_APP_ENV`, `APPSIGNAL_PUSH_API_KEY`                                                    | AppSignal monitoring             |
| `WALLABY_AUTH_USERNAME`, `WALLABY_AUTH_PASSWORD`                                                 | Basic auth for screenshot worker |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUCKET_NAME`, `AWS_ENDPOINT_URL_S3`, `AWS_REGION` | S3/Tigris uploads                |

AppSignal revision is read from `priv/REVISION` at boot.

**Exception to "no `System.get_env` in lib/"**: Release task modules in `lib/elixir_drops/release.ex` may use `System.get_env` — these modules run before the OTP app starts, so `Application.get_env` is not available. The rule targets runtime app code, not release tasks.

## Testing Patterns

- **Ecto sandbox** — `:sql_sandbox` config toggles the `LiveAcceptance` on_mount in router `live_session` blocks.
- **Async feature tests** — enabled via `FeatureCase` with `async: true`; database ownership is passed through via User-Agent metadata (Phoenix.Ecto.SQL.Sandbox pattern). ~4.5x faster than serial.
- **PhoenixTest.Playwright** — `conn` param is a browser session, not `Plug.Conn`. Tests run on `localhost:#{PORT_TEST}` (default 4100) with real Chromium.
- **Mox** — stub `ElixirDrops.S3Helper` via `Application.put_env(:elixir_drops, :s3_helper, MockClient)`.
- **ExMachina factories** in `test/support` — prefer over raw `Repo.insert/1` for deterministic data.
- **Coverage** — `coveralls.json` excludes test support files.
- **DOM-mutation instruments** — For detecting subtle timing bugs (e.g., items painted unpositioned): use `Frame.evaluate/2` to inject a MutationObserver init script immediately after `visit/1`, which persists on `window` and tracks specific DOM conditions (visibility, inline styles). Read results via `Frame.evaluate/2` again. Prefer this over relying on CLS (cumulative layout shift) metrics, which read ≈0 in headless even when layout is broken.
  - Example: masonry append-flash test detects newly-appended `.masonry-item` nodes that are `offsetParent !== null` (visible) AND have no inline `style.left` / `style.top` (unpositioned). Samples on both MutationObserver callback time AND the next `requestAnimationFrame` to avoid timing windows. Metric: `flashed_count == 0` (no visible-but-unpositioned items ever detected).
- **Playwright Frame.evaluate scroll-event delivery** — `window.scrollBy` via `Frame.evaluate` changes `window.scrollY` but does NOT reliably fire a `scroll` event in headless Chromium (event-delivery timing is non-deterministic in JS evaluation context). Tests using scroll listeners must either: (a) explicitly dispatch `dispatchEvent(new Event('scroll'))` after `scrollBy` to ensure listeners fire, or (b) call hook methods directly via element property refs (e.g., `void marker._hookRef.loadMore()`) to bypass scroll wiring entirely. The `Frame.evaluate` timeout (`PW_TIMEOUT` default 500ms) also awaits Promise return values — calling an async hook method without `void` will block `evaluate` until the async chain resolves, which may timeout if the hook internally awaits image-loading or other slow events. Use `void asyncFn()` to make `evaluate` return a synchronous value instead.

## Key Patterns

- **Context boundaries** — public APIs only; cross-context references use fully-qualified aliases (e.g., `ElixirDrops.Accounts.User` from Drops).
- **Binary IDs everywhere** — `generators: [timestamp_type: :utc_datetime, binary_id: true]`.
- **Embedded schemas** — e.g. `Drop.screenshot` with `on_replace: :update`.
- **Alphabetical attrs** — `attr` declarations and HEEx call sites sorted alphabetically for consistency.
- **HEEx formatting** — empty elements with whitespace normalize to self-closing form (`<span>\n  </span>` → `<span />`); no structural rewrites, only formatter-driven changes.
- **Route verification** — `~p` sigil for static routes; string interpolation for dynamic routes that the verifier can't prove.
- **Credo strict** — zero-tolerance; `optimum_credo` config. Lint rules: name underscore-prefixed match variables (e.g., `{:ok, _reason}` not `{:ok, _}`); for repeated `_` in same scope, reuse the semantic name (e.g., `{:ok, _popular}` × 5 in a test does not trigger rebound warnings); `length(x) > 0` → `x != []` (O(1) empty-list compare vs O(n) length), applies in HEEx `:if` attrs too (`@suggestions != []` not `length(@suggestions) > 0`). Exception: count comparisons like `length(@items) > 3` for pagination are NOT converted — only presence checks (`> 0` / `== 0`) are substituted.
- **Prettier** — run on everything via `npx prettier -c .`; `prettier-plugin-toml` installed.

## Common Pitfalls

- **Missing `attr` declarations** cause silent template failures — every HEEx parameter needs a corresponding `attr`.
- **`~p` sigil vs string routes** — static routes must use `~p`, dynamic fragments must interpolate; mixing causes compile errors.
- **Credo variable shadowing** — rename shadowed vars in nested scopes; Credo strict flags them.
- **Feature test race conditions** — single `Repo.get_by!` beats multi-query lookups; never use `List.last(Drops.list_drops())` in assertions.
- **LiveView sandbox in async tests** — `LiveAcceptance` on_mount is required; relies on User-Agent encoding.
- **PhoenixTest.Playwright helper wrappers** — avoid custom helpers that unwrap/return `nil`; use native `PhoenixTest` APIs.
- **Matching Chrome/ChromeDriver** — prod Docker image must pin versions for Wallaby.
- **`priv/REVISION`** — generated at deploy; don't edit or commit manually.
