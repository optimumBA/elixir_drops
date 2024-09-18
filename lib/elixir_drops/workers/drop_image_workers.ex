defmodule ElixirDrops.Workers.DropImageWorkers do
  @moduledoc """
  Background job for creating a drop image
  """
  use Oban.Worker, queue: :drop_images

  alias ElixirDropsWeb.Endpoint

  alias ElixirDrops.S3Helper.Client

  require Logger

  @topic "image_upload_status"

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{"image" => image_binary, "name" => name, "type" => type} = args

    filename = "#{Ecto.UUID.generate()}_#{name}"

    [_metadata, image] = String.split(image_binary, ",")

    decoded_image = Base.decode64!(image)

    Client.upload_image(filename, decoded_image, type)

    broadcast_upload_status({:ok, "new image uploaded"}, "pole")

    :ok
  end

  defp broadcast_upload_status({:ok, url}, name) do
    Endpoint.broadcast(@topic, "image_upload_success", %{
      "url" => url,
      "image_name" => name
    })
  end

  defp broadcast_upload_status(_error, name) do
    Endpoint.broadcast(@topic, "image_upload_fail", %{"image_name" => name})
  end
end
