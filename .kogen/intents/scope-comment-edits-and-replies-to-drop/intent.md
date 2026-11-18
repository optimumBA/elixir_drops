# Scope comment edits and replies to their Drop

Slug: scope-comment-edits-and-replies-to-drop
Model: not applicable — two stateless authorization and validation predicates with no multi-step state worth modelling
Acceptance:
- .kogen/intents/scope-comment-edits-and-replies-to-drop/acceptance.feature
- features/steps/scope-comment-edits-and-replies-to-drop__run.js
- features/steps/scope-comment-edits-and-replies-to-drop__driver/comment_write_scope_test.exs

A comment write must only touch the author's own comment on the Drop being viewed. Deletion already follows this (`Comments.delete_comment/3`). This change finishes the other two writes, recorded as G01 and G02 in `spec/implementation-gaps.md`.

Editing. The `update_comment` event of `lib/elixir_drops_web/live/comment/form_component.ex` currently loads the client-supplied comment ID with the unscoped `get_comment!/1` and the page then calls the unscoped `Comments.update_comment/2`, so any signed-in user can edit any comment by forging the event. Replace this with `Comments.edit_comment(user, drop, comment_id, attrs)` in `lib/elixir_drops/comments.ex`: it matches the comment ID together with the author (`user_id`) and the Drop (`drop_id`) in the query and returns `{:ok, comment}` (body saved, `edited_at` set to the current time by the context), `{:error, %Ecto.Changeset{}}` for invalid attrs (existing validation, 1000 character limit unchanged), or `{:error, :not_found}` for any other ID (another author's comment, a comment of another Drop, an unknown UUID, a malformed or nil ID) without changing any stored row and without raising. The component no longer loads the comment or sets `edited_at`; it forwards the comment ID and the form params to the page, and the page (`lib/elixir_drops_web/live/drop_live/show.ex`) calls `edit_comment` with the server-assigned `current_user` and `drop`. A not-found result, or no signed-in user, leaves the page working and shows the flash error `That comment could not be edited.`; the existing `Your changes were not saved. Try again.` flash stays for invalid attrs. The author's own edit works as today (text saved, "Edited" marker, the updated thread re-rendered). The unscoped `Comments.update_comment/2` is removed (nothing else uses it) and its unit tests are replaced by `edit_comment/4` tests; `get_comment!/1` stays because other code uses it.

Replies. `Comments.create_comment/4` additionally refuses a parent comment whose `drop_id` differs from the new comment's Drop: the changeset is invalid with the error `must belong to the same drop` on `:parent_id`, nothing is inserted, and (because the page only creates notifications after a successful insert) no notification is created. A reply to a top-level comment of the same Drop works as today and the existing `replies cannot have replies` error on `:parent_id` stays.

Documentation. Update the G01 and G02 rows of `spec/implementation-gaps.md` (and the matching mentions of G01/G02 in `spec/domain.md` C01/C02 and `spec/coverage.md`) to state what is now enforced (edit scoped to author and viewed Drop by `Comments.edit_comment/4`; same-Drop parent check in `Comments.create_comment/4`) and what is not (for example `change_edit_comment_form` still loads a supplied ID with `get_comment!/1`, and `create_comment` in the page still loads the supplied parent ID with `get_comment!/1`), with no claim beyond the tests.

Out of scope: schema change or migration, sign-in flow, notification behavior for valid writes, markdown rendering, the 1000 character limit, new dependencies, moderation rights.

Acceptance runs one self-contained ExUnit file with four tests against the real Drop LiveView and the local test database using synthetic fixtures, observed through `mix test`, once for all four scenarios. The unchanged behavior (author's own edit through the real form, same-Drop reply, reply-to-reply refusal) is asserted inside scenarios 1, 3 and 4. The existing `test/elixir_drops/comments_test.exs` and `test/elixir_drops_web/live/drop_live/show_test.exs` are extended in their current style with the same rules.

## Decisions
- Edits go through `Comments.edit_comment(user, drop, comment_id, attrs)`, matching comment ID, author and Drop in the query, returning ok, a changeset error or `{:error, :not_found}`; the user and Drop come from server socket assigns, never from the client. (decision: D1, round 1) (constraint: no client identity is trusted; malformed IDs return not-found without raising) (evidence: lib/elixir_drops/comments.ex; lib/elixir_drops_web/live/comment/form_component.ex; lib/elixir_drops_web/live/drop_live/show.ex) (source: request)
- `edited_at` is set by the context on a successful edit, replacing the component's merge of `edited_at` into client params. (decision: D2, round 1) (evidence: lib/elixir_drops_web/live/comment/form_component.ex; lib/elixir_drops/comments/comment.ex) (source: request)
- A rejected edit shows the flash error `That comment could not be edited.` in the existing `put_flash(:error, ...)` style. (decision: D3, round 1)  (evidence: lib/elixir_drops_web/live/drop_live/show.ex) (assumption: the exact wording of the short plain message is acceptable to the product) (source: request)
- The cross-Drop parent refusal is the changeset error `must belong to the same drop` on `:parent_id`, alongside the unchanged `replies cannot have replies`; a parent that is itself a reply keeps the existing error. (decision: D4, round 1)  (evidence: lib/elixir_drops/comments.ex) (assumption: the exact message wording is acceptable to the product) (source: request)
- The unscoped `Comments.update_comment/2` is removed and its tests replaced; `get_comment!/1` is kept. (decision: D5, round 1) (evidence: lib/elixir_drops/comments.ex; test/elixir_drops/comments_test.exs; lib/elixir_drops_web/live/drop_live/show.ex) (source: request)
- Acceptance runs a helper ExUnit file under features/steps with `mix test --trace <file>` once per feature run, judging each named test from trace output plus the summary line, as the deletion Intent does. (decision: D6, round 1)  (evidence: features/steps/authorize-comment-deletion-by-user-and-drop__run.js; test/support/conn_case.ex) (assumption: mix test accepts the helper file outside test/ and finishes within the 120 s step limit; not run to completion in shaping) (source: request)
- The forged event in acceptance targets the sender's own mounted edit form component with another user's comment ID, since the server must reject it regardless of which component carries the event. (decision: D7, round 1) (evidence: lib/elixir_drops_web/live/comment_components.ex; test/elixir_drops_web/live/drop_live/show_test.exs) (source: request)
- Controls are deferred: hand-built overlay diffs for three production files could not be verified with `git apply` inside the budget; each of the four acceptance tests nonetheless fails on current main (old behavior) and asserts the specified wrong-implementation properties. (decision: D8, round 1) (assumption: The request is silent on deferring wrong-implementation controls; it requires those implementations to fail the checks, and this decision adds an unverified process claim with no request or answer support.) (source: request)

## Source comparison
- Author edit returns ok with new body and edited timestamp: scenario "The author edits their own comment" (source: request).
- Other author, other Drop, unknown UUID and malformed ID return not-found and leave the row byte for byte unchanged: scenario "Other comments cannot be edited" (source: request).
- Cross-Drop parent refused with error on the parent, no row, no notification; same-Drop reply and reply-to-reply refusal preserved: scenario "A reply must stay on the Drop of its parent" (source: request).
- LiveView forged edit by user B on A's comment changes nothing and shows the plain error; A's real form edit still updates the thread: scenario "A forged edit event changes nothing" (source: request).
- Updating G01/G02 rows of spec/implementation-gaps.md: documentation change verified by `make spec` and review, not acceptance (source: request).
- No schema change, sign-in, notification, markdown or length-limit change; no dependencies: unchanged (source: request).
- Signed GitHub-verified landing and checked deployment path: delivery process outside this Intent's executable acceptance (source: request).

## Tests
- Author edit returns ok with saved body and edited timestamp; not-found cases leave rows unchanged: edit_comment/4 tests in test/elixir_drops/comments_test.exs replacing the update_comment/2 tests (unit)
- Cross-Drop parent refused with no row, same-Drop reply works, reply to reply refused: create_comment tests in test/elixir_drops/comments_test.exs (unit)
- Forged update_comment event from another user changes nothing and shows the error; author edit still updates the thread: tests in test/elixir_drops_web/live/drop_live/show_test.exs (regression)
- All four rules through the real LiveView and context: the isolated ExUnit file run by the four acceptance scenarios (scenario)
- Other comment and Drop page behavior: existing tests (existing)

## Feasibility
- none
