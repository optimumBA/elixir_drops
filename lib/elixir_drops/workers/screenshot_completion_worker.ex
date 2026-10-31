defmodule ElixirDrops.Workers.ScreenshotCompletionWorker do
  @moduledoc false

  use Oban.Worker, queue: :seo_images, max_attempts: 5

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Workers.SitemapGeneratorWorker

  @type action :: String.t() | nil
  @type drop :: Drop.t()
  @type job_result :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}

  @spec enqueue(drop(), action()) :: job_result()
  def enqueue(drop, action) do
    scheduled_at = DateTime.add(DateTime.utc_now(), 1_500, :millisecond)

    %{
      "action" => action,
      "body_digest" => body_digest(drop.body),
      "drop_id" => drop.id,
      "internal_url" => drop.screenshot.internal_url,
      "meta_url" => drop.screenshot.meta_url
    }
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    expected_internal_url = args["internal_url"]
    expected_meta_url = args["meta_url"]

    case Drops.get_drop(%{drop_id: args["drop_id"]}) do
      %Drop{screenshot: %{status: :completed, internal_url: internal_url, meta_url: meta_url}} =
          drop
      when internal_url == expected_internal_url and meta_url == expected_meta_url ->
        complete_if_current(drop, args)

      %Drop{} ->
        {:error, "Screenshot completion no longer matches this drop"}

      nil ->
        {:error, "Drop not found"}
    end
  end

  defp complete_if_current(drop, args) do
    if body_digest(drop.body) == args["body_digest"] do
      with {:ok, _job} <- enqueue_sitemap(drop) do
        Drops.broadcast_drop_screenshot_completion(drop, 100, :completed, %{
          action: args["action"]
        })
      end
    else
      {:error, "Screenshot completion no longer matches this drop"}
    end
  end

  defp body_digest(body) do
    digest = :crypto.hash(:sha256, body)
    Base.encode16(digest, case: :lower)
  end

  defp enqueue_sitemap(drop) do
    %{"drop_id" => drop.id}
    |> SitemapGeneratorWorker.new()
    |> Oban.insert()
  end
end
