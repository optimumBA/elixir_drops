# Derived content and background delivery

Executable owners: [delivery.qnt](../quint/delivery.qnt), composed with content in
[system.qnt](../quint/system.qnt). [SEO operations](../docs/seo.md) owns generation
and deployment procedures rather than duplicating them here.

## Screenshots

**I01 — selection (baseline).** Only the first recognized fenced code block determines
a screenshot. No block means `skipped` and absent generated URLs. New/different first
code means `pending`, cleared URLs and an image-job attempt. Changes only to prose or
later blocks reuse an available image. The contract preserves a failed/pending state
when unchanged code has no successful image; current form code incorrectly promotes
that to completed (G05). ImageCode in the model is the identity of the first block,
not the whole body or a real URL.

**I02 — pipeline (baseline).** An Oban `seo_images` worker has at most five attempts.
FLAME/Chrome captures two PNGs: social `meta` and internal card. Both upload operations
must succeed before persisting `completed` with both URLs; partial upload/failure
keeps no published URL pair and marks failed. A failed attempt may leave an orphan
storage object; automatic object cleanup is not promised. The displayed failure state
can coexist with a queued retry. Successful completion broadcasts 100% and attempts
to queue sitemap regeneration. Progress is in 0–100 and can reset between attempts.
Exceptions/crashes are also Oban retry inputs; caught failures and UI failure delivery
are not identical in current code (G11).

**I03 — concurrent saves (refinement, G04).** A worker using older code must not replace
images for newer current code, or clear a newer successful image on failure. The model
fences completion/failure by first-code identity. Production object names currently
use stable `latest-<drop UUID>` paths; preventing overwrite also requires fencing the
storage operation or using immutable versioned keys. A database-only fence would not
establish the complete rule. This is proposed protection, not implemented behavior.

**I04 — admission failures (baseline).** Drop save, job enqueue, external capture,
upload, notification insert and PubSub delivery are distinct failure boundaries.
An ignored job-enqueue failure can leave a saved Drop permanently pending without a
job. `saveWithEnqueue(..., false)` makes that state executable. There is no transactional
outbox or automatic reconciliation in this baseline. The composed model checks
successful enqueue admission; the delivery model separately checks failed enqueue.
Neither model promises eventual completion when scheduling/services keep failing.

## Markdown and cache

**M01 — representations (baseline).** A Drop Markdown document includes `# <title>`,
the original body, a separator, author username, formatted creation date and its HTML
URL. `/index.md` contains all saved Drops, newest first with ID tie-break, their Markdown
links, author/date and a summary from the first nonempty non-heading line (200-character
summary with ellipsis when longer). Source currently bounds index bodies to 500 bytes;
Unicode-boundary truncation remains an implementation concern, not a model operation.

**M02 — caching (baseline intent).** Cache entries expire strictly after less than
300 seconds; the boundary is a miss. Successful content/image writes invalidate the
server Drop/index caches. Cache hits may serve without a database query. Versioned
keys/explicit invalidation must prevent serving a pre-edit representation after a
completed save. The model abstracts one server/cache and logical versions. It does
not prove concurrent generation-versus-invalidation or remote-node ETS invalidation;
those are G07. External HTTP caches can legitimately retain responses for the published
`max-age=300`; server invalidation does not revoke a browser/CDN copy.

## Archive, sitemap and metadata

**E01 — complete discovery (baseline).** `/archive` is server-rendered HTML with normal
links to every public Drop, grouped by publication month. It includes pending/failed
image Drops even though the homepage hides them. No header archive link is introduced.
`/index.md` canonicalizes to `/archive`; each Drop Markdown route canonicalizes to its
HTML page. The homepage, archive and existing Drop page self-canonicalize. Private and
utility pages do not inherit the homepage canonical.

**E02 — sitemap lifecycle (baseline).** The sitemap contains the homepage, `/archive`
and every saved Drop once, in complete newest-first collection order, with `lastmod`
from each Drop's `updated_at` date. Every successful publication attempts to queue
generation (after screenshot completion when screenshots are needed). The worker has
at most three attempts. Rebuild from current data, serialize writers, write a temporary
file and atomically replace the final file. Failed/in-progress writes must leave the
last complete file intact. The model uses Drop IDs and a collection version; it omits
the two fixed URLs, XML escaping and filesystem implementation, covered by source tests.
A saved Drop can appear after a later rebuild; queue/file failures can leave stale
output. Generation is not a guarantee of crawler fetches, indexing or ranking.

**E03 — rendering and metadata (baseline).** HTML Markdown supports the current MDEx
extensions (tables, strikethrough, underline, autolinks, tasks, footnotes and shortcodes),
syntax highlighting and escaped raw HTML. Copying code preserves raw text. Standard
metadata uses escaped titles/descriptions and correct page canonicals. A Drop description
combines title and plain-text body, strips code/markup, and is capped at 160 characters.
A completed meta screenshot supplies social image metadata; otherwise use the site's
fallback. JSON-LD is an Article with publication/modification dates, author, publisher,
image and canonical identity; escape script-ending sequences. Actual image dimensions
and safe Unicode/text escaping are source/browser-test obligations; the model checks
availability, not serialized pixels or JSON-LD bytes.

## Runtime boundary

Current Ecto/PostgreSQL, Oban, PubSub, FLAME, S3/Tigris, MDEx and caches are implementation
choices. Release migrations, durable database/storage backups, secrets, observability
and browser-driver versions remain operational requirements outside this finite model.
The spec does not assert multi-machine consistency, disaster recovery, latency budgets,
exactly-once delivery or a new SQLite deployment. Existing operations remain their owners.
