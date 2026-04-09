# Authentication (GitHub OAuth)

## Architecture

Users authenticate via GitHub OAuth using Ueberauth. On callback, the app derives a user record from GitHub profile fields, persists it, and starts a signed session (optionally with a remember-me cookie). A dev-only bypass exists for browser tests and local development.

Flow: user hits `/auth/github` -> `Ueberauth.Strategy.Github` redirects to GitHub -> callback hits `/auth/github/callback` -> `GithubAuthController.callback/2` extracts profile -> `Accounts.get_or_create_user/1` by `github_id` -> `Accounts.clear_all_tokens_for_user/1` -> `UserAuth.log_in_user/3` renews session, writes remember-me cookie, redirects to `user_return_to` or root.

## Schema

- `users` — `id` (binary_id), `avatar`, `email`, `github_id` (unique), `github_username`, `name`, timestamps. `has_many :drops`, `has_many :search_histories`.
- `users_tokens` — session tokens for cookie-based auth and remember-me (`_elixir_drops_web_user_remember_me`, signed, `max_age` 60 days, SameSite Lax).

## Auth Modules

| Module                                | Purpose                                                                                                                             |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `ElixirDrops.Accounts`                | User context — `get_or_create_user/1`, `get_user_by_github_id/1`, tokens                                                            |
| `ElixirDrops.Accounts.User`           | Schema with GitHub profile fields                                                                                                   |
| `ElixirDrops.Accounts.UserToken`      | Session token schema                                                                                                                |
| `ElixirDropsWeb.UserAuth`             | Plug + LiveView on_mount hooks (`log_in_user`, `log_out_user`, `fetch_current_user`, `ensure_authenticated`, `assign_current_user`) |
| `ElixirDropsWeb.GithubAuthController` | Ueberauth request/callback, logout                                                                                                  |
| `ElixirDropsWeb.DevAuthController`    | Dev-only `/dev/auth/:user_id` bypass (gated by `:dev_routes`)                                                                       |

## Routes

- `get "/auth/:provider", GithubAuthController, :request` — starts Ueberauth flow.
- `get "/auth/:provider/callback", GithubAuthController, :callback`.
- `get "/auth/logout", GithubAuthController, :logout`.
- `get "/dev/auth/:user_id", DevAuthController, :enable` — only mounted when `:dev_routes` is enabled.

Protected routes use `:require_authenticated_user` pipeline and `ensure_authenticated` on_mount: `/profile`, `/drops/new`, `/drops/:short_id/edit`.

## Auth Env Vars

| Variable               | Purpose                              |
| ---------------------- | ------------------------------------ |
| `GITHUB_CLIENT_ID`     | Ueberauth GitHub OAuth client id     |
| `GITHUB_CLIENT_SECRET` | Ueberauth GitHub OAuth client secret |

## Auth Pitfalls

- **Ueberauth plug order** — `plug :store_return_to when action in [:request]` must precede `plug Ueberauth` in `GithubAuthController` so return URLs survive the redirect.
- **Clear tokens on login** — `Accounts.clear_all_tokens_for_user/1` runs before `log_in_user` to drop stale sessions; don't skip.
- **Dev auth bypass in tests** — `:dev_auth_bypass` and `:sql_sandbox` are only `true` in `config/test.exs`; feature tests rely on this to impersonate users without going through GitHub.
- **Return-to sanitization** — `store_return_to` only persists when `return_to` is a binary param; guard downstream consumers.
