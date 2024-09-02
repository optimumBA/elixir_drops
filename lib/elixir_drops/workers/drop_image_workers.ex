defmodule ElixirDrops.Workers.DropImageWorkers do
  @moduledoc """
  Background job for creating a drop image
  """
  use Oban.Worker, queue: :drop_images, max_attempts: 1

  alias ElixirDrops.Accounts
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Client

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"image" => image, "filename" => filename, "type" => type, "user_id" => user_id}
      }) do
    case Client.upload_image(image, filename, type) do
      {:ok, url} ->
        user = Accounts.get_user!(user_id)
        attrs = %{image_url: url}

        case Drops.create_drop(%Drop{}, user, attrs) do
          {:ok, drop} -> {:ok, drop}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, reason} ->
        {:error, "image upload failed"}
    end
  end
end
