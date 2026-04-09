# Search

## Architecture

PostgreSQL full-text search over drops with per-user history and popularity tracking. Search suggestions follow a 2+3 rule: authenticated users see 2 recent history entries plus 3 popular matches; anonymous users see 5 popular matches. Search UI is a navbar dropdown with mobile full-screen overlay.

Flow: user types in navbar search -> debounced suggestion fetch -> `Search.get_search_suggestions/2` -> returns history + popular. On submit -> query flows into `Drops.list_drops/2` via `:search` filter -> PostgreSQL `websearch_to_tsquery('english', ...)` matches `drops.search_vector` and `ts_rank` orders results -> `Search.create_search_history/1` and `Search.create_or_increment_popular_search/1` record the query.

## Schema

- `drops.search_vector` — `tsvector` maintained by PostgreSQL, GIN-indexed, `load_in_query: false`.
- `search_histories` — belongs_to user, `query`, timestamps. Last 100 per user, deduped by query.
- `popular_searches` — `query` (unique), `count`, atomic increment.

## Search Modules

| Module                             | Purpose                                                          |
| ---------------------------------- | ---------------------------------------------------------------- |
| `ElixirDrops.Search`               | Context — history CRUD, popular tracking, suggestions (2+3 rule) |
| `ElixirDrops.Search.SearchHistory` | Per-user search log schema                                       |
| `ElixirDrops.Search.PopularSearch` | Query -> count schema with atomic increment                      |
| `ElixirDropsWeb.NavbarSearchHook`  | LiveView on_mount hook exposing search state to all pages        |
| `ElixirDropsWeb.SearchHelper`      | Navbar search component and suggestion rendering                 |

## Public API

- `Search.get_search_suggestions(user_id, query_prefix)` — returns `[%{type:, query:, ...}]`; applies 2+3 rule.
- `Search.get_popular_search_suggestions(query_prefix, limit \\ 5)`.
- `Search.get_user_search_history(user_id, limit \\ 100)` — deduped, most recent first.
- `Search.create_or_increment_popular_search(query)` — atomic upsert.
- `Search.delete_search_history(search_history_id, user_id)` — deletes all occurrences of that query for the user.

## Query Matching

- `Drops.list_drops/2` with `%{search: query}` filter applies `fragment("? @@ websearch_to_tsquery('english', ?)", drop.search_vector, ^query)`.
- Ordering uses `ts_rank(drop.search_vector, websearch_to_tsquery(...))` descending; non-search queries order by `inserted_at` desc.

## Search Pitfalls

- **Empty query strings** — `apply_filter({:search, _}, dynamic)` is a no-op for non-binary or empty strings; guard at call site.
- **Suggestion debounce** — keep ~100ms debounce in the navbar hook to avoid query storms.
- **History dedup** — `Enum.uniq_by(& &1.query)` runs after `Repo.all`; do not rely on DB-level uniqueness.
- **Popular search seeding** — seed file exists; don't re-seed in tests, use factories instead.
