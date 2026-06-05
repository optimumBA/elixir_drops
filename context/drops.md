# Drops

## Architecture

Core snippet sharing domain. Drops are code snippets with markdown body, author, screenshot, and full-text search vector. Real-time PubSub fan-out for creation and screenshot progress. Public timeline rendered in a masonry layout with viewport-aware infinite scroll. Comments and user notifications are tied to drops.

Flow: user creates drop via `UserDropLive.FormComponent` -> `Drops.create_drop/2` -> `broadcast_drop_creation/1` -> `DropLive.Index` receives via PubSub and prepends to stream -> `ScreenshotGeneratorWorker` enqueued -> progress broadcasts update card.

## Schema

- `drops` — `id` (binary_id), `title`, `body`, `short_id` (unique, 8-char), `search_vector` (tsvector, GIN-indexed, `load_in_query: false`), `screenshot` (embedded), `user_id`, timestamps. Virtual: `comment_count`, `relevance_rank`.
- `drops.screenshot` (embedded) — `internal_url`, `meta_url`, `status` (enum: `:pending`, `:completed`, `:failed`, `:skipped`).
- `comments` — belongs_to drop and user, supports parent_comment for replies.
- `notifications` — per-user feed driven by comments, scoped PubSub `"notifications-#{user_id}"`.

## Drops Modules

| Module                                   | Purpose                                                               |
| ---------------------------------------- | --------------------------------------------------------------------- |
| `ElixirDrops.Drops`                      | Context — list/get/create/update, filters, search ordering, broadcast |
| `ElixirDrops.Drops.Drop`                 | Ecto schema with embedded screenshot                                  |
| `ElixirDrops.Drops.Screenshot`           | Embedded schema with status enum                                      |
| `ElixirDrops.Drops.ShortIdGenerator`     | Generates 8-char unique `short_id`                                    |
| `ElixirDrops.Comments`                   | Comment CRUD, threaded replies                                        |
| `ElixirDrops.Comments.Comment`           | Comment schema (belongs_to Drop, User, parent Comment)                |
| `ElixirDrops.Notifications`              | Per-user notification feed, PubSub per user_id                        |
| `ElixirDrops.Notifications.Notification` | Notification schema                                                   |
| `ElixirDrops.Sitemap`                    | XML sitemap generation, per-drop updates                              |
| `ElixirDrops.StructuredData`             | JSON-LD structured data for SEO                                       |

## LiveView Modules

| Module                                      | Route(s)                                          | Purpose                                         |
| ------------------------------------------- | ------------------------------------------------- | ----------------------------------------------- |
| `ElixirDropsWeb.DropLive.Index`             | `/`                                               | Public timeline with masonry, infinite scroll   |
| `ElixirDropsWeb.DropLive.Show`              | `/d/:short_id`                                    | Single drop view with comments                  |
| `ElixirDropsWeb.UserDropLive.Index`         | `/profile`, `/drops/new`, `/drops/:short_id/edit` | Authenticated CRUD of user's own drops          |
| `ElixirDropsWeb.UserDropLive.FormComponent` | -                                                 | Drop create/edit form                           |
| `ElixirDropsWeb.Comment.FormComponent`      | -                                                 | Comment create form                             |
| `ElixirDropsWeb.DropsListHelper`            | -                                                 | Shared drops list component (infinite scroll)   |
| `ElixirDropsWeb.DropsBatchCalculator`       | -                                                 | Viewport-based batch sizing (6-40, 1-5 columns) |
| `ElixirDropsWeb.DropComponents`             | -                                                 | Drop card rendering components                  |
| `ElixirDropsWeb.CodeSnippetController`      | `/d/:id/code_snippet`                             | Renders snippet HTML for screenshot capture     |

## PubSub Topics

| Topic                        | Events                                                                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `inspect(ElixirDrops.Drops)` | `[:drop, :created]`, `[:drop, :screenshot_generation_started]`, `[:drop, :screenshot_generation_completion]` (with progress 0-100, status, metadata) |
| `"notifications-#{user_id}"` | New-comment notifications per recipient                                                                                                              |

## Masonry Layout

- CSS Grid + `masonry-layout` JS + `imagesloaded`.
- `DropsBatchCalculator.calculate_batch_size/2` — columns by width (<=480: 1, <=768: 2, <=1400: 3, <=1800: 4, else: 5), rows by `(height - 200) / 350`, clamped 6-40.
- Assets: `assets/js/hooks/masonry.js`, `assets/js/hooks/infinite_scroll.js`, `assets/css/components/masonry.css`.
- Page behavior differs: homepage shows "New Drops" button on PubSub insert; user profile auto-refreshes.

## Masonry Append Flash Fix

**The Problem**: When infinite scroll appends new `.masonry-item` nodes to the DOM, the hook initially defers the append work (`appended()` + `layout()`) via `setTimeout(150)` or similar. During this gap, appended items render in static document flow (stacked, full width) because they have no inline `position:absolute` / `left` / `top` styles yet — Masonry only sets those during `layout()`. Result: ~150ms visual flash of unpositioned items before they snap into grid columns.

**The Fix**: Masonry items are now hidden (`opacity:0; visibility:hidden` via the `.masonry-item-pending` CSS class) the moment they enter the DOM (synchronous in `updated()`), then revealed only after `layout()` completes and positioned them. Visibility is gated until positioning.

- **Timing**: `masonry.js` `updated()` adds `.masonry-item-pending` class to new items before any defer. Append work runs via `requestAnimationFrame` (replaced `setTimeout(150)`), which is faster and more predictable. After `imagesloaded` callback + `layout()` set inline positions, a double-`requestAnimationFrame` removes the pending class, revealing now-positioned items.
- **CSS**: `.masonry-item.masonry-item-pending { opacity: 0; visibility: hidden; }` in `masonry.css`. Using `visibility:hidden` (not `display:none`) preserves box dimensions, so `imagesloaded` and `layout()` can measure items correctly.
- **Mid-Flight Destroy Safeguard**: If Masonry is destroyed (reconnect/search reset) between the append rAF and `imagesloaded` callback resolution, an `else` branch in `appendNewItems` unconditionally removes the pending class, revealing items in their current layout (no longer Masonry-managed, which is correct). Additionally, `initializeMasonry` strips any lingering `.masonry-item-pending` nodes before rebuilding Masonry, covering the case where reset fires after the rAF but before `imagesloaded` resolves.

## Notification Timing

Comment submission triggers an async PubSub broadcast to the drop author's `"notifications-#{user_id}"` topic. The author's LiveView session receives the notification via `handle_info(:notification, ...)`. Tests that assert notification count must force a message-queue drain on the commenting LiveView BEFORE mounting the author's viewer session, else the assertion races the async broadcast. Pattern: add `render(view)` flush after `render_submit()` and before the next `sign_in_user()` / mount of the author's session. This forces the commenting LiveView to complete a synchronous round-trip, draining its inbox first.

## Drops Pitfalls

- **Masonry append flash (FIXED)** — newly appended items painted visible-but-unpositioned during the gap between DOM insertion and `layout()` execution. Fixed via synchronous `.masonry-item-pending` class (opacity:0, visibility:hidden), rAF-based defer (not `setTimeout`), and double-rAF reveal after layout. Mid-flight Masonry destroy is guarded: `appendNewItems` else branch reveals on null masonry, and `initializeMasonry` strips any lingering pending nodes before re-init.
- **Stream resets cause visual glitches** — use page reset instead of `stream(:drops, drops, reset: true)`.
- **CSS class collisions** — masonry `.drop-body` was renamed `.drop-full-content` to avoid affecting show page. Namespace component CSS.
- **Flaky tests from multi-query lookups** — use `Repo.get_by!` with specific filters, not `List.last(Drops.list_drops())`.
- **Search ordering** — `apply_search_ordering/2` injects `ts_rank(...)` via `select_merge`; don't drop it when composing queries.
- **Sandbox errors surface as empty lists** — `safe_list_drops/2` rescues `DBConnection.OwnershipError` / `ConnectionError` and returns `[]`.
- **Pagination vs. presence checks** — lint rule converts `length(items) > 0` → `items != []` (O(1) empty-list compare), but NOT count comparisons like `length(@suggested_searches) > 3` (pagination sentinel for "show row if 4+ items"). Only presence checks (`> 0` / `== 0`) are substituted.
