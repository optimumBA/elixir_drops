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

**Credo placement in CI chain**: Credo runs BEFORE dialyzer and the test step. A credo failure exits with `Error 6` and produces NO test summary line (`N tests, M failures`). When reading a gate log, always confirm the test-summary line exists before classifying a gate failure as a test regression — a missing summary indicates a static-stage failure (compile, credo, dialyzer, format, prettier, audit) not a test failure. Easy to misread a credo abort as a test failure.

No dialyzer plt cache on disk for this repo — `plt_file` is `priv/plts/dialyzer.plt`.

**Asset freshness in tests**: `endpoint.ex` uses `gzip: Application.compile_env(:elixir_drops, :serve_gzip_assets, true)` (prod default true). Test and dev override to `false` in their config files (`config/test.exs:77-81`, `config/dev.exs:111`). When `gzip: true`, Plug.Static serves `priv/static/assets/js/app.js.gz` (if present) in preference to the plain `app.js`. Only `phx.digest` (in `assets.deploy`) regenerates `.gz`; bare `mix assets.build` only regenerates the plain file. A stale `.gz` from a prior branch can shadow source edits, causing feature tests to load old (possibly broken) JS while the source has been fixed. Result: test sees stale behavior, development work appears ineffective. Fix: (1) `mix.exs` `test` alias includes `assets.build` to keep plain `.js` current; (2) `gzip: false` in test env so only the fresh plain file is served. Pre-existing broken test runs may have a stale `.gz` on disk — `mix assets.build` clears the shadow by regenerating the plain file correctly.

**`Phoenix.LiveView.stream/4` `limit:` behavior**: the `limit:` option applies `Enum.take(all_children, limit)` to ALL children of the `phx-update="stream"` container, including non-stream `:if` divs and static layout elements (e.g., `<div class="grid-sizer">`). Non-stream children consume limit slots and displace stream items. When doing a full `reset: true` that fetches exactly `batch_size` items, the `limit:` is redundant and harmful — remove it. If layout elements are needed, place them OUTSIDE the stream container (e.g., append-only fragment with `phx-update="append"`).

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

- **Ecto sandbox** — `:sql_sandbox` config toggles the `LiveAcceptance` on_mount in router `live_session` blocks. **CRITICAL**: `Sandbox.mode/2` must ONLY be called by the sandbox OWNER (the test process in `DataCase.setup_sandbox`), never from an allowed child like a LiveView `on_mount`. Calling `mode({:shared, self()})` from `on_mount` replaces the global shared owner and causes subsequent LV queries to land on a different connection that cannot see test-transaction data. Use `Sandbox.allow/2` alone in `on_mount` — it is sufficient. **For `async: true` LiveView tests** — `ConnCase` setup must inject encoded sandbox metadata via `Phoenix.Ecto.SQL.Sandbox.metadata_for(Repo, self()) |> encode_metadata()` into the conn's `user-agent` header. Without it, `on_mount`'s `get_connect_info(socket, :user_agent)` returns `nil` and the LV process is never sandbox-allowed, causing DB queries to see an empty database (test data is invisible). Add `if connected?(socket)` guard in `on_mount` (dead render has no WebSocket connect_info). **Detached Tasks (fire-and-forget from `Task.start`)** have no `$callers` and are never sandbox-allowed in tests — they get killed mid-insert when the owner exits, surfacing as benign-looking `DBConnection.ConnectionError owner exited` log noise that masks real test failures. Use `Task.Supervisor.start_child(MyApp.TaskSupervisor, fn -> ... end)` instead — it propagates `$callers` so the sandbox checks the caller's allowance chain and grants access transitively. Ensure a `Task.Supervisor` instance is in the supervision tree (`always:` tag for all environments).
- **Async feature tests** — enabled via `FeatureCase` with `async: true`; database ownership is passed through via User-Agent metadata (Phoenix.Ecto.SQL.Sandbox pattern). ~4.5x faster than serial.
- **PhoenixTest.Playwright** — `conn` param is a browser session, not `Plug.Conn`. Tests run on `localhost:#{PORT_TEST}` (default 4100) with real Chromium.
- **Mox** — stub `ElixirDrops.S3Helper` via `Application.put_env(:elixir_drops, :s3_helper, MockClient)`.
- **ExMachina factories** in `test/support` — prefer over raw `Repo.insert/1` for deterministic data.
- **Ranked-query test fixtures** — when testing `ORDER BY <ranking_col> DESC LIMIT N` suggestions/rankings, test fixtures must use ranking values STRICTLY ABOVE any seed/fixture data already in the DB. Otherwise seed data always outranks the test's expected terms and assertions fail. Example: if seeds set max `search_count: 20`, use `search_count: 100+` in test fixtures so they rank top-3. Confirms determinism by running the test with multiple seeds.
- **Coverage** — `coveralls.json` excludes test support files.
- **DOM-mutation instruments** — For detecting subtle timing bugs (e.g., items painted unpositioned): use `Frame.evaluate/2` to inject a MutationObserver init script immediately after `visit/1`, which persists on `window` and tracks specific DOM conditions (visibility, inline styles). Read results via `Frame.evaluate/2` again. Prefer this over relying on CLS (cumulative layout shift) metrics, which read ≈0 in headless even when layout is broken.
  - Example: masonry append-flash test detects newly-appended `.masonry-item` nodes that are `offsetParent !== null` (visible) AND have no inline `style.left` / `style.top` (unpositioned). Samples on both MutationObserver callback time AND the next `requestAnimationFrame` to avoid timing windows. Metric: `flashed_count == 0` (no visible-but-unpositioned items ever detected).
- **Playwright Frame.evaluate scroll-event delivery** — `window.scrollBy` via `Frame.evaluate` changes `window.scrollY` but does NOT reliably fire a `scroll` event in headless Chromium (event-delivery timing is non-deterministic in JS evaluation context). Tests using scroll listeners must either: (a) explicitly dispatch `dispatchEvent(new Event('scroll'))` after `scrollBy` to ensure listeners fire, or (b) call hook methods directly via element property refs (e.g., `void marker._hookRef.loadMore()`) to bypass scroll wiring entirely. The `Frame.evaluate` timeout (`PW_TIMEOUT` default 500ms) also awaits Promise return values — calling an async hook method without `void` will block `evaluate` until the async chain resolves, which may timeout if the hook internally awaits image-loading or other slow events. Use `void asyncFn()` to make `evaluate` return a synchronous value instead.
- **`@feature` tests REQUIRE `FEATURE_TESTS=true`** — `config/test.exs:24,29` sets `server: System.get_env("FEATURE_TESTS") == "true"`. A bare `mix test --include feature ...` runs with `server: false` → Phoenix endpoint never boots → Playwright navigates to a dead :4100 → every `Frame.evaluate` hangs to the 120s `@moduletag timeout` → looks like a "pool-exhaustion" error (ownership_timeout disconnect) but is a server-not-booted hang. The canonical run path is `mix test.features` (mix.exs alias) or inline `FEATURE_TESTS=true mix test --include feature ...`. The **dev-gate `**Gate**:`line MUST carry`FEATURE_TESTS=true` inline** so gate-select.sh's clean SubagentStop shell (which does not inherit the dev session's env) boots the server before running the test.
- **Self-synchronizing scroll helper pattern for slow gate machines** — a feature-test loop that fires an event then uses a fixed `Process.sleep(N)` + recount fails on slow CI machines because the server round-trip (event→DB query→stream append→LV diff→WS push→DOM patch) does NOT complete within the fixed window. Robust pattern: after firing the event ONCE, poll IN-PAGE (via `Frame.evaluate` with explicit `timeout:` larger than the poll deadline) until the OBSERVABLE outcome (item count grows / endOfTimeline) or deadline expires. Remove dependence on fixed sleep. Example: `scroll_down/2` in `test/support/feature_helpers.ex` fires `hook.loadMore()` once then polls in-page for `.masonry-item` count > startCount, up to 8s, with `Frame.evaluate(..., timeout: 10_000)`. This is machine-speed-independent and avoids duplicate-firing problems on non-idempotent server cursors.
- **WS-disconnect → hook-loss failure mode (DISPROVEN for masonry test)** — When the LiveView WebSocket disconnects under machine load/latency, LiveView tears down all hooks. Any test helper that drives behavior via a per-DOM-element hook property (e.g., `el._infiniteScrollHook`) becomes a silent no-op: the property is set only in `mounted()` and cleared on disconnect. The failure presents as a clean timeout (no crash), because the guarded `if (marker && marker._infiniteScrollHook)` call simply doesn't fire. This is a REAL mechanism for hook-property-driven tests, but was NOT the root cause of the masonry test's 48s timeout — diagnostic evidence showed hook WAS present and WS WAS connected; the actual cause was the server round-trip exceeding the test's fixed 1000ms recount window (see self-synchronizing pattern above).
- **dev-gate `pool-exhaustion` classification false-positive**: The gate's classifier greps bare `DBConnection.ConnectionError` strings to detect pool starvation. This over-matches benign sandbox teardown noise: when an async test exits while a `Task.Supervised` still holds a checked-out connection, Ecto logs `owner #PID exited` / `is still using a connection` (harmless, task is cleaned up). These lines trigger the "pool-exhaustion" INCONCLUSIVE classification even when there is no real starvation. True starvation signals are distinct: `connection not available and request was dropped from queue`, `all workers busy`, `ownership_timeout`, `ExUnit.TimeoutError`. When a gate reports INCONCLUSIVE pool-exhaustion, read the full log for the test-summary line (`N tests, M failures`): if the summary shows failures, they are the real issue, not pool exhaustion. If tests passed and pool-exhaustion was reported, it is a false-positive triggered by teardown noise.
- **`Frame.evaluate/3` timeout semantics** — `opts` list is merged via `Enum.into` into the Playwright params map; a `timeout:` key in opts becomes `params.timeout` and is picked up by `Connection.post/1`'s `update_in(~w(params timeout)a, ...)`. With no explicit `timeout:`, the global `PW_TIMEOUT` (default 500ms, `config/test.exs`) applies. Async IIFEs that poll in-page for more than 500ms MUST pass `timeout: N` (N > poll window) or `Frame.evaluate` raises a timeout error.
- **Dialyzer + runtime:false deps** — when a dep like `phoenix_test_playwright` is `runtime: false`, dialyzer excludes it from the default PLT and cannot resolve calls into that module, raising "function does not exist" warnings. Fix: add the app to `plt_add_apps: [...]` in `mix.exs` dialyzer config (`plt_add_apps: [:ex_unit, :mix, :phoenix_test_playwright]`). Dialyzer will rebuild the PLT on next run (~30–60s) and include the app's analysis, clearing the warnings. No semantic risk — the PLT is a static analysis artifact, not a runtime classpath. **NOTE**: adding a dep to `plt_add_apps` exposes its real types and may surface latent mismatches in downstream code (e.g., a helper's `@type session :: %Mod{}` bare-struct alias will be flagged as non-overlapping if the dep declares `@opaque t() :: %Mod{}`). The mismatch is real and fixing it (alias to `Mod.t()` instead of the struct) is correct — the dep's opacity is a strict contract.
- **Opaque types + bare-struct aliases** — when a dep declares `@opaque t() :: %__MODULE__{}` and downstream code uses `@type foo :: %Mod{}` (bare struct literal) in a spec, they do NOT overlap per dialyzer (from outside the defining module). Always alias to the opaque type name: `@type foo :: Mod.t()`. Fixing a downstream alias from struct to opaque can reveal secondary `opaque_match` warnings in functions that do structural pattern-matching (`%{field: var} = opaque_val`) — replace with dot access (`opaque_val.field`) when accessing fields of an opaque value from outside its module.

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
