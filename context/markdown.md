# Markdown Export

## Architecture

Every drop is exposed as raw markdown for LLM consumption and Livebook integration. Two endpoints: `/index.md` (all drops, truncated bodies) and `/d/:short_id.md` (single drop). Results are cached in ETS with a 5-minute TTL matching the HTTP `Cache-Control: max-age=300` header. A plug interceptor handles the `.md` suffix because Phoenix routes don't support file extensions in dynamic params.

Flow: request `/d/abc12345.md` -> `MarkdownInterceptor` binary-matches `/d/<8-char>.md` -> calls `MarkdownController.show/2` directly and `halt()`s the conn -> controller checks `MarkdownCache.get_cached_drop_content/1` -> on miss loads drop and calls `MarkdownCache.get_or_generate/3` with `MarkdownFormatter.format_drop/1` -> response served with `text/markdown` and `x-content-type-options: nosniff`.

## Markdown Modules

| Module                                     | Purpose                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------- |
| `ElixirDrops.MarkdownFormatter`            | Drop -> markdown string (iolist-based); `format_drop/1`, `format_index/1` |
| `ElixirDrops.MarkdownCache`                | ETS cache with TTL, per-drop and index match specs                        |
| `ElixirDropsWeb.MarkdownController`        | `/index.md` and `show/2` for individual drops; cache-first lookups        |
| `ElixirDropsWeb.Plugs.MarkdownInterceptor` | Binary-size pattern match for `<<short_id::binary-size(8), ".md">>`       |

## Routes & Pipeline

- Dedicated `:markdown` pipeline — `accepts: ["markdown", "text"]`, `put_resp_content_type "text/markdown"`. No session, no CSRF.
- `get "/index.md", MarkdownController, :index` declared in router.
- `/d/:short_id.md` is NOT in the router — `MarkdownInterceptor` runs in the `:browser` pipeline, matches the path, calls `MarkdownController.show/2` directly, and halts.

## Cache Keys

- `{:drop, short_id, timestamp_key}` where `timestamp_key` is a minute-resolution integer derived from `updated_at`.
- `{:index, :erlang.phash2/1}` of `[{short_id, timestamp_key}, ...]` — any drop change invalidates the index.
- Lookups use `:ets.select/2` with match specs (`:"$1"`, `:"$2"`) so callers can resolve by `short_id` without the full drop struct.
- `clear_drop/1` deletes the drop entry and every `:index` entry (index may reference it).

## Content Format

- `format_drop/1` — `# Title` / body / `---` / `Created by: <github_username>` / `Date: <Month DD, YYYY>` / `URL: <url>`.
- `format_index/1` — header + `## [Title](url.md)` per drop with first non-heading content line (truncated at 200 chars) as description.
- `Drops.list_all_drops/0` preloads user and truncates `body` to 500 bytes per drop for the index.

## Markdown Pitfalls

- **ETS table race** — `ensure_cache_table/0` rescues `ArgumentError` so concurrent creators don't crash. Don't remove the rescue.
- **Short-ID length is hardcoded** — `binary-size(8)` in the interceptor is coupled to `ShortIdGenerator`; changing length breaks `.md` routing.
- **Cache-first then DB** — always check `get_cached_*_content/*` before hitting `Drops`; controller pattern is `{:hit, content} | :miss` -> `handle_cache_miss_for_*`.
- **404 serves markdown too** — `serve_not_found/1` returns `text/plain` 404 with a markdown heading body; consistent with CLI clients that follow redirects.
