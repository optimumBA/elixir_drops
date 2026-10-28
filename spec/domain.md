# Identity, content and discussion

Executable owner: [app.qnt](../quint/app.qnt). Cross-component admission:
[system.qnt](../quint/system.qnt). Source owners are linked in [coverage](coverage.md).

## Accounts and sessions

**A01 — GitHub identity (baseline).** A validated OAuth profile creates or retrieves
one user by unique GitHub ID. Avatar, email, GitHub ID, username and name are required
by registration. Existing users are reused; current code does not refresh their
profile on each login. Invalid OAuth or invalid registration must not create a
session. The model's user number represents a previously validated GitHub identity;
provider responses and concurrent registration uniqueness are implementation checks.

**A02 — token lifecycle (baseline).** Successful GitHub login clears that user's old
stored tokens, generates a fresh session token, renews/clears the browser session,
and writes a signed remember-me cookie. The stored token is valid for strictly less
than 60 days from issuance; it is invalid at the boundary. A cookie restores a
missing browser-session token only when the backing token remains valid. Logout
revokes the active token, clears session/cookie and disconnects its live socket.
Multiple browsers can retain old cookie bytes but cannot authenticate new requests
with revoked tokens. Token entropy, signing, CSRF and TLS are platform contracts.

**A03 — access boundary (baseline intent).** Visitors can read public content and
search. A valid authenticated principal is required for `/profile`, new/edit Drop
flows, comment writes, private history deletion and marking notifications read.
Identity is server-derived. Never accept an actor/owner from client form fields.
Application entry points must enforce these checks; hidden controls are not checks.
The model validates a token at command admission; existing warm LiveView revocation
semantics are an explicit refinement in G10, not a proven runtime property.

## Drops

**D01 — validation and identity (baseline).** Publishing requires nonblank title and
body, with title length at most 255 characters. Ecto trims blank strings; the model
uses post-normalization lengths. There is no extra body-size limit. The author comes
from the session. Generate a unique eight-character short ID independently of client
input, retrying a collision before reporting success. The model uses unique finite
Drop IDs in place of generated UUIDs and short IDs; collision retry remains a source
test obligation. Public URLs use the short ID, screenshot routes use the UUID.

**D02 — edits (baseline intent).** Only the author edits an existing Drop. Preserve
its identity, author and creation time; update its content/modification time. The
model revision is a logical content version, not a promised optimistic-lock field.
Rejected, invalid or missing-target commands leave persisted content unchanged and
must not enqueue derived work. Successful saves invalidate server Markdown caches.
There is no application Drop-delete command in this baseline.

**D03 — publication (baseline).** A saved Drop exists publicly immediately: there is
no draft or approval column. Screenshot status can keep it out of the homepage;
it does not remove its detail page, archive or Markdown representation. Profiles
include the author's pending/failed Drops. Creating a Drop broadcasts a creation
message; image progress/completion uses separate messages. Broadcasts are transient;
reconnect reloads persistent state and must not rely on replay of past PubSub events.

## Comments and replies

**C01 — creation (baseline plus access intent).** Signed-in users can write comments
of 1–1000 characters on an existing Drop. They can reply to an existing top-level
comment on the same Drop. Replies cannot have replies. Cross-Drop parents are rejected
by the contract even though current context code only checks depth (G02).

**C02 — edits/deletion (baseline intent).** Only the comment author can edit or delete
it. An edit preserves author, Drop and parent, and records `edited_at`. Physical
parent deletion cascades to direct replies and all notifications referencing them;
reply deletion leaves its parent. The total displayed count includes replies; the
pagination count includes top-level comments only. There is no soft-delete state
or implicit moderator override. Server authorization is currently missing (G01).

**C03 — reading (baseline).** Top-level comments are ordered by insertion time then
ID, newest first, in pages of 10 using offset. Each root preloads its replies,
newest first. A reply deep link opens the parent container and locates the comment.
Concurrent inserts can move offset page boundaries; snapshot pagination for comments
is not claimed. Deleting a root requires updating both total and root counts (G11).

## Notifications

**N01 — recipients (baseline).** A root comment notifies the Drop author if different
from the actor. A reply notifies the root author as `reply_to_comment`, and also the
Drop author as `comment_on_post` if that person differs from both root author and
actor. If root and Drop author are the same person, send the reply notice only.
Never notify the actor about their own action. Each notice belongs to its recipient.

**N02 — independent failure (baseline).** Comment persistence precedes notification
insertion. An insert can fail while the comment remains saved; failure is swallowed
and is not a durable automatic retry promise. The model separates pending attempts
from successfully stored notices to explore this window. A successful notice is
broadcast on `notifications-<recipient_id>`; that broadcast is not durable storage.

**N03 — read state (baseline).** The feed contains unread notices only, newest first,
in pages of 10. Counts are unread counts. Mark-all-read affects only the current
recipient, preserves stored notices and empties that recipient's live unread view.
A subsequent notice is unread. Comment deletion removes its notices through foreign
keys. Timestamp-only notification cursors can omit tied entries (G03).
