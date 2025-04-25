defmodule ElixirDrops.S3Helper.Client do
  @moduledoc false

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Http

  @type drop :: Drop.t()
  @type filename :: binary()
  @type image :: binary()
  @type type :: binary()
  @type url :: binary()

  @callback upload_image(image(), filename(), type()) :: {:ok, url()} | {:error, any()}

  @spec upload_image(image(), filename(), type()) :: {:ok, url()} | {:error, any()}
  def upload_image(image, filename, type) do
    impl().upload_image(
      image,
      filename,
      type
    )
  end

  defp impl, do: Application.get_env(:elixir_drops, :s3_helper, Http)
end
