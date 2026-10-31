defmodule ElixirDrops.Workers.ScreenshotCompletionWorkerTest do
  # Completion events share the application-wide Drops topic.
  use ElixirDrops.DataCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Workers.ScreenshotCompletionWorker
  alias ElixirDrops.Workers.SitemapGeneratorWorker

  @moduletag serial: :pubsub

  describe "enqueue/2" do
    test "persists completion at least 1500 milliseconds after scheduling" do
      drop = drop_fixture(user_fixture())
      Drops.subscribe()
      before = DateTime.utc_now()

      assert {:ok, job} = ScreenshotCompletionWorker.enqueue(drop, "edit")
      assert DateTime.diff(job.scheduled_at, before, :millisecond) >= 1_500
      assert job.state == "scheduled"
      assert job.args["action"] == "edit"
      refute_enqueued(worker: SitemapGeneratorWorker)
    end
  end

  describe "perform/1" do
    test "broadcasts completed progress and schedules a sitemap for the current screenshot" do
      drop = drop_fixture(user_fixture())
      Drops.subscribe()

      assert :ok =
               perform_job(ScreenshotCompletionWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 body_digest: body_digest(drop.body),
                 internal_url: drop.screenshot.internal_url,
                 meta_url: drop.screenshot.meta_url
               })

      assert_receive {Drops, [:drop, :screenshot_generation_completion], updated_drop, 100,
                      :completed, %{action: "edit"}}

      assert updated_drop.id == drop.id
      assert_enqueued(worker: SitemapGeneratorWorker, args: %{"drop_id" => drop.id})
    end

    test "returns a retryable error without announcing a missing drop" do
      Drops.subscribe()

      assert {:error, "Drop not found"} =
               perform_job(ScreenshotCompletionWorker, %{drop_id: Ecto.UUID.generate()})

      refute_receive {Drops, [:drop, :screenshot_generation_completion], _, 100, :completed, _}
      refute_enqueued(worker: SitemapGeneratorWorker)
    end

    test "does not announce a screenshot that is no longer completed" do
      user = user_fixture()
      drop = drop_fixture(user)
      assert {:ok, _drop} = Drops.update_drop(drop, user, %{screenshot: %{status: :failed}})
      Drops.subscribe()

      assert {:error, "Screenshot completion no longer matches this drop"} =
               perform_job(ScreenshotCompletionWorker, %{
                 drop_id: drop.id,
                 action: "new",
                 body_digest: body_digest(drop.body),
                 internal_url: drop.screenshot.internal_url,
                 meta_url: drop.screenshot.meta_url
               })

      refute_receive {Drops, [:drop, :screenshot_generation_completion], _, 100, :completed, _}
      refute_enqueued(worker: SitemapGeneratorWorker)
    end

    test "does not announce a screenshot for an earlier body" do
      drop = drop_fixture(user_fixture())
      Drops.subscribe()

      assert {:error, "Screenshot completion no longer matches this drop"} =
               perform_job(ScreenshotCompletionWorker, %{
                 drop_id: drop.id,
                 action: "edit",
                 body_digest: "older body digest",
                 internal_url: drop.screenshot.internal_url,
                 meta_url: drop.screenshot.meta_url
               })

      refute_receive {Drops, [:drop, :screenshot_generation_completion], _, 100, :completed, _}
      refute_enqueued(worker: SitemapGeneratorWorker)
    end

    test "does not announce a superseded screenshot" do
      drop = drop_fixture(user_fixture())
      Drops.subscribe()

      assert {:error, "Screenshot completion no longer matches this drop"} =
               perform_job(ScreenshotCompletionWorker, %{
                 drop_id: drop.id,
                 action: "new",
                 body_digest: body_digest(drop.body),
                 internal_url: "old internal URL",
                 meta_url: "old meta URL"
               })

      refute_receive {Drops, [:drop, :screenshot_generation_completion], _, 100, :completed, _}
      refute_enqueued(worker: SitemapGeneratorWorker)
    end
  end

  defp body_digest(body) do
    digest = :crypto.hash(:sha256, body)
    Base.encode16(digest, case: :lower)
  end
end
