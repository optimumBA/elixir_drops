defmodule ElixirDrops.ImageCreationWorker do
  @moduledoc false

  alias ElixirDrops.Accounts
  use Oban.Worker, queue: :media, max_attempts: 3
  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropsSeoTagsExtractor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"drop_id" => drop_id, "user_id" => user_id}}) do
    case create_drop_seo_image(drop_id, user_id) do
      {:ok, drop} ->
        store_seo_image_in_tigris(drop)

      _error ->
        maybe_update_failure_creation(drop_id)
    end

    :ok
  end

  defp create_drop_seo_image(drop_id, user_id) do
    drop = Drops.get_drop(drop_id)
    user = Accounts.get_user!(user_id)
    seo_image = DropsSeoTagsExtractor.create_drop_meta_image(drop)

    Drops.update_drop(
      drop,
      user,
      %{"seo_image_link" => seo_image}
    )
  end

  defp store_seo_image_in_tigris(drop) do
    # Implement success logic here
    IO.puts("Drop #{drop.id} SEO image creation successful: #{drop.seo_image_link}")
    :ok
  end

  defp maybe_update_failure_creation(drop) do
    # Implement failure logic here
    IO.puts("Drop #{drop.id} SEO image creation failed")
    :error
  end
end
