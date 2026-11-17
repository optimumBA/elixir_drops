# Authorize comment deletion by user and Drop

Slug: authorize-comment-deletion-by-user-and-drop
Model: not applicable — a single authorization predicate on one event with no multi-step state worth modelling
Acceptance:
- .kogen/intents/authorize-comment-deletion-by-user-and-drop/acceptance.feature
- features/steps/authorize-comment-deletion-by-user-and-drop__run.js
- features/steps/authorize-comment-deletion-by-user-and-drop__driver/comment_deletion_authorization_test.exs

The Drop page `lib/elixir_drops_web/live/drop_live/show.ex` handles the `delete_comment` event by fetching the client-supplied `comment_id` and calling `Comments.delete_comment/1` in `lib/elixir_drops/comments.ex`, which deletes by comment ID alone. Any visitor, including a guest, can delete any comment by forging the event. The change makes deletion require a server-derived authenticated current user and bind the lookup and the mutation to BOTH that user (the comment author) and the Drop the page currently shows (`socket.assigns.drop`, derived from the URL on the server). A submitted comment ID that is not the current user's comment on the viewed Drop changes nothing: no persisted comment, reply, related row or count changes, the displayed thread is unchanged and the LiveView stays alive. Hiding the delete control is not sufficient. The existing successful same-author, same-Drop deletion is preserved, including live thread updates, counts, and the existing cascade (a deleted top-level comment removes its replies; a deleted reply leaves its parent). Out of scope: moderation rights, soft deletion, OAuth changes and any unrelated feature. The unscoped `Comments.delete_comment/1` is replaced, not kept beside the scoped form; its existing unit test in `test/elixir_drops/comments_test.exs` and the existing LiveView test in `test/elixir_drops_web/live/drop_live/show_test.exs` are updated to the scoped behavior.

Acceptance runs a self-contained ExUnit file owned by this Intent against the real LiveView and the local test database using only synthetic records from the existing fixtures. It is observed through `mix test`, whose result is parsed by the step.

## Decisions
- Deletion is bound to the authenticated `current_user` and the viewed `drop` taken from server socket assigns; the client-supplied `comment_id` is the only client input and is matched against both `user_id` and `drop_id` in the lookup and the delete query. (constraint: guests are rejected; no client user or Drop identity is read) (evidence: lib/elixir_drops_web/live/drop_live/show.ex; lib/elixir_drops/comments.ex) (source: request)
- A rejected attempt is a silent no-op that leaves the LiveView process alive and the thread unchanged; no new flash or UI copy is added. (decision: D2, round 1) (assumption: the product accepts a silent no-op for a forged event rather than an error message) (source: request)
- The unscoped `Comments.delete_comment/1` is replaced by a scoped function taking the user, Drop and comment ID, and existing tests of the old form are updated. (decision: D3, round 1) (evidence: lib/elixir_drops/comments.ex; test/elixir_drops/comments_test.exs; test/elixir_drops_web/live/drop_live/show_test.exs) (source: request)
- Acceptance runs a helper ExUnit file located under features/steps with `mix test <file>` once per feature run (output cached) and judges each named test from `--trace` output plus the summary line. The helper only needs the existing ConnCase, fixtures and database. (decision: D4, round 1) (evidence: test/support/conn_case.ex; test/support/fixtures/comments_fixtures.ex; mix.exs) (assumption: mix test accepts an explicit test file outside test/ and finishes within the 120 s step limit on the acceptance host; not probed to completion in shaping) (source: request)
- Maintained contract text spec/domain.md (C02 and gap G01) is updated proportionately if it describes missing server authorization; no moderation rules are added. (decision: D5, round 1) (evidence: spec/domain.md) (source: request)
- Bind comment deletion to server-derived current_user and the viewed Drop (decision: D1, round 1) (constraint: guests rejected) (constraint: no client identity trusted) (evidence: lib/elixir_drops_web/live/drop_live/show.ex; lib/elixir_drops/comments.ex) (assumption: Acceptance runs mix test on a helper file outside test/; not probed to completion within the 120 s step limit.) (source: request)

## Source comparison
- Guest deletion rejected with unchanged rows/count/thread: scenario "A guest cannot delete a comment" (source: request).
- Authenticated user A cannot delete B's comment: scenario "An authenticated user cannot delete another author's comment" (source: request).
- A cannot delete A's comment of Drop Y while viewing Drop X: scenario "An authenticated user cannot delete a comment of a different Drop" (source: request).
- Same-author same-Drop deletion succeeds for top-level comments and replies with correct counts and thread: scenarios "The author deletes a top-level comment" and "The author deletes a reply" (source: request).
- Moderation, soft deletion, OAuth, unrelated features: omitted (source: request).
- Full gate (format, compile warnings as errors, strict Credo, Sobelow, unused deps, full tests, make spec when spec bytes change): retained project checks, not acceptance (source: request).

## Tests
- Guest, other-author and other-Drop deletion are rejected without mutation: helper ExUnit regressions run by the acceptance scenarios, plus equivalent regressions added to test/elixir_drops_web/live/drop_live/show_test.exs (regression)
- Author deletion of a top-level comment or reply works with correct count and thread: acceptance scenarios and the updated delete test in show_test.exs (scenario)
- Scoped context function deletes only the matching user and Drop comment: update the delete_comment tests in test/elixir_drops/comments_test.exs (unit)
- Other Drop page behavior: existing show_test.exs (existing)

## Feasibility
- none
