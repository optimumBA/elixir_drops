# Search and archive pages

`ElixirDrops.Drops.list_all_drops/0` is the collection source for both `/archive`
and `/index.md`. The archive is the compact, crawler-readable HTML list of every
public Drop; the Markdown index keeps its summaries for existing consumers. The
Markdown index canonicalizes to `/archive` because both expose the same complete
Drop collection. A Drop's `.md` representation canonicalizes to that Drop's HTML
page. The latest-first masonry homepage remains a separate, self-canonical page.

The SEO metadata component owns the standard description and any explicitly
assigned canonical. The home LiveView, Drop LiveView and archive controller assign
their own canonical URLs; utility and authenticated pages do not inherit the home
canonical. Drop descriptions combine the title and a Markdown-stripped body
summary, escaped by HEEx when emitted. The sitemap is generated from the same
complete Drops query, includes `/archive`, and keeps each Drop's existing
`updated_at` date as `lastmod`.

Every successful Drop publication queues sitemap generation. The worker rebuilds
the complete current collection so creates, edits and removed Drops cannot leave
an appended or stale entry. Writes are serialized in the application and replace
the sitemap atomically. Ordering follows `inserted_at` newest first for a stable
collection view; it is a consistency choice and makes no search-ranking claim.

## Discovery

`robots.txt` advertises `/sitemap.xml`, which includes `/archive` and every
public Drop. The archive exposes ordinary HTML links to those Drops. The header
has no archive link, per the owner’s design preference; no hidden link is used.
An `Allow: /archive` directive would control crawl permission, not request
discovery, so it is unnecessary with the current robots rules. Sitemap discovery
is a hint and does not guarantee crawling or indexing.

## Local verification

From the repository root:

Use `mise exec --` for Mix and Make commands so `.tool-versions` selects the
project's pinned Elixir and Erlang versions.

1. Run `mise exec -- mix test test/elixir_drops_web/controllers/archive_controller_test.exs`.
2. Run the Markdown controller, Drop LiveView and sitemap tests, then `mise exec -- make ci`.
3. Open `/archive`, `/`, a Drop HTML page, `/index.md`, a Drop `.md` URL, and
   `/robots.txt`; confirm complete archive links, self-canonicals, Markdown Link
   headers, and the sitemap location.

After an authorized production deployment, submit the updated sitemap once in
Google Search Console, record the submission date and reported fetch state, then
reopen the property later to verify processing. A successful submission is not a
promise of indexing or ranking.
