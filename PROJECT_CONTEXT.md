# elixir_drops - Project Context

## Project Overview

- **Purpose**: Code snippet sharing platform for Elixir developers. Drops are markdown-backed snippets with auto-generated social/internal screenshots, full-text search, comments, and markdown export for LLMs.
- **Architecture**: Phoenix 1.8 + LiveView 1.1, PostgreSQL (full-text search via tsvector), Oban for background jobs, FLAME for distributed screenshot generation on Fly.io, Tigris/S3 for image storage, AppSignal for monitoring.
- **Data Flow**: User submits drop via LiveView -> `Drops` context -> PubSub broadcast to timeline -> Oban enqueues `ScreenshotGeneratorWorker` -> FLAME -> Wallaby/Chrome -> S3 upload -> progress broadcast -> sitemap regenerated.
- **Key Integrations**: GitHub OAuth (Ueberauth), Tigris/S3, FLAME on Fly.io, Oban, AppSignal, PhoenixTest.Playwright + Wallaby.

## Domain Context Files

Detailed context is split by business domain. **Load the index (this file) always. Load domain files only when relevant to your task.**

| File                     | Domain                                                                                              | Load when working on...                                                   |
| ------------------------ | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `context/drops.md`       | Drops context, schema, LiveViews, masonry, batch sizing, comments, notifications, PubSub broadcasts | Drop CRUD, timeline UI, masonry/infinite scroll, comments, notifications  |
| `context/search.md`      | PostgreSQL full-text search, suggestions (2+3 rule), history, popular tracking                      | Navbar search, query ordering, search history, popular counters           |
| `context/screenshots.md` | FLAME pool, `ScreenshotGeneratorWorker`, Wallaby capture, S3 upload, sitemap worker                 | Screenshot generation, FLAME config, Oban image queues, S3/Tigris uploads |
| `context/markdown.md`    | `.md` routes, `MarkdownFormatter`, `MarkdownCache` (ETS + TTL), `MarkdownInterceptor` plug          | Markdown endpoints, LLM export, ETS cache, binary-pattern route matching  |
| `context/auth.md`        | GitHub OAuth, Ueberauth, `UserAuth` session/remember-me, dev auth bypass                            | Auth flow, session hooks, protected routes, dev login                     |
| `context/development.md` | Tech stack, `make ci`, testing, env vars, setup, pitfalls, Wallaby/Playwright                       | CI failures, env config, writing tests, debugging, project setup          |

### Loading examples

- **New drop field or list filter**: `drops.md` (+ `search.md` if it touches `search_vector`)
- **Screenshot worker bug**: `screenshots.md` (+ `development.md` for env vars)
- **`.md` route or cache change**: `markdown.md`
- **GitHub OAuth callback fix**: `auth.md`
- **Flaky feature test**: `development.md` (+ the domain file the test covers)
