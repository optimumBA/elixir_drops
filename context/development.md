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
2. `mix ci` alias: `deps.unlock --check-unused` -> `deps.audit` -> `hex.audit` -> `sobelow --config .sobelow-conf --compact --quiet` -> `format --check-formatted` -> `cmd npx prettier -c .` -> `credo --strict --format oneline` -> `dialyzer --quiet-with-result` -> `test --cover --warnings-as-errors`
3. `MIX_ENV=test mix ecto.rollback --all --quiet`

No dialyzer plt cache on disk for this repo — `plt_file` is `priv/plts/dialyzer.plt`.

## Test Commands

- `mix test` — unit + integration (Ecto sandbox, no server).
- `mix coveralls` / `mix coveralls.html` — coverage report.
- `mix test.features` — browser tests: deploys assets then `FEATURE_TESTS=true mix test --only feature`.
- Playwright env vars: `PW_HEADLESS`, `PW_SCREENSHOT`, `PW_TIMEOUT`, `PW_TRACE`.
- `PORT_TEST` overrides the feature-test port (default 4100).

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

## Testing Patterns

- **Ecto sandbox** — `:sql_sandbox` config toggles the `LiveAcceptance` on_mount in router `live_session` blocks.
- **Async feature tests** — enabled via `FeatureCase` with `async: true`; database ownership is passed through via User-Agent metadata (Phoenix.Ecto.SQL.Sandbox pattern). ~4.5x faster than serial.
- **PhoenixTest.Playwright** — `conn` param is a browser session, not `Plug.Conn`. Tests run on `localhost:#{PORT_TEST}` (default 4100) with real Chromium.
- **Mox** — stub `ElixirDrops.S3Helper` via `Application.put_env(:elixir_drops, :s3_helper, MockClient)`.
- **ExMachina factories** in `test/support` — prefer over raw `Repo.insert/1` for deterministic data.
- **Coverage** — `coveralls.json` excludes test support files.

## Key Patterns

- **Context boundaries** — public APIs only; cross-context references use fully-qualified aliases (e.g., `ElixirDrops.Accounts.User` from Drops).
- **Binary IDs everywhere** — `generators: [timestamp_type: :utc_datetime, binary_id: true]`.
- **Embedded schemas** — e.g. `Drop.screenshot` with `on_replace: :update`.
- **Alphabetical attrs** — `attr` declarations and HEEx call sites sorted alphabetically for consistency.
- **Route verification** — `~p` sigil for static routes; string interpolation for dynamic routes that the verifier can't prove.
- **Credo strict** — zero-tolerance; `optimum_credo` config.
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
