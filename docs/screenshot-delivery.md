# Screenshot completion and recovery

The screenshot generator uploads both image variants, persists the completed
screenshot, and enqueues `ScreenshotCompletionWorker` for at least 1,500 ms later.
The generator no longer sleeps while holding its worker process. This delay
retains the existing allowance for object-storage propagation; it does not prove
that the remote objects are readable.

The completion worker reloads the Drop and checks its completed status, image
URLs and body digest. Only a matching result can enqueue sitemap generation and
broadcast 100% completion with the original action. A missing, failed or
superseded Drop returns an error without announcing completion. Enqueue errors
propagate to Oban; both workers allow up to five attempts.

Two generations with identical body and stable image URLs remain indistinguishable.
A generation token would be needed to fence that race completely. Completion
retries are not a claim of exactly-once sitemap jobs or broadcasts.

## Verify and resume

1. Start in the repository root with its pinned mise environment and an isolated
   test database selected through `MIX_TEST_PARTITION`.
2. Run `mix test test/elixir_drops/workers/screenshot_generator_worker_test.exs
test/elixir_drops/workers/screenshot_completion_worker_test.exs` as one command.
3. Run the repository's full `make ci` gate before committing. Its rollback step
   must use that isolated test database. Use browser tests for editor/realtime
   changes; worker tests alone do not establish browser or storage behavior.
4. For a failed live job, inspect its actual arguments, attempt and stored Drop
   state before retrying through the application's normal Oban recovery route.
   Preserve the failure evidence; do not manually broadcast a successful result.

Completion requires the scheduled-time and no-immediate-completion assertions,
current-image sitemap/broadcast checks, stale/missing/status/body/URL rejection
checks and the applicable project gates. Live storage and deployment remain
separate verification boundaries.
