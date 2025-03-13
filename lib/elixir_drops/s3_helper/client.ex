defmodule ElixirDrops.S3Helper.Client do
  @moduledoc false

  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.S3Helper.Http

  @type drop :: Drop.t()
  @type filename :: binary()
  @type image :: binary()
  @type screenshot_type :: :meta | :internal
  @type content_type :: binary()
  @type url :: binary()

  @callback get_image(drop(), screenshot_type()) :: {:ok, url()} | {:error, any()}
  @callback upload_image(image(), filename(), content_type()) :: {:ok, url()} | {:error, any()}

  @spec upload_image(image(), filename(), content_type()) :: {:ok, url()} | {:error, any()}
  def upload_image(image, filename, type) do
    impl().upload_image(
      image,
      filename,
      type
    )
  end

  @spec get_image(drop(), screenshot_type()) :: {:ok, url()} | {:error, any()}
  def get_image(drop, type \\ :meta), do: impl().get_image(drop, type)

  defp impl, do: Application.get_env(:elixir_drops, :s3_helper, Http)
end
