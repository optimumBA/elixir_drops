defmodule ElixirDrops.S3Helper.Client do
  @moduledoc false

  alias ElixirDrops.S3Helper.Http

  @type filename :: binary()
  @type image :: binary()
  @type retries :: non_neg_integer()
  @type type :: binary()
  @type url :: binary()

  @callback upload_image(image(), filename(), type(), retries()) :: {:ok, url()} | {:error, any()}

  @spec upload_image(image(), filename(), type(), retries()) :: {:ok, url()} | {:error, any()}
  def upload_image(image, filename, type, retries \\ 0) do
    upload_fun = fn ->
      impl().upload_image(
        image,
        filename,
        type,
        retries
      )
    end

    retry_upload(upload_fun.(), image, filename, type, retries)
  end

  defp retry_upload({:ok, url}, _image, _filename, _type, _retries), do: {:ok, url}

  defp retry_upload({:error, _error}, image, filename, type, retries) when retries < 3 do
    upload_image(image, filename, type, retries + 1)
  end

  defp retry_upload(response, _image, _filename, _type, _retries), do: response

  defp impl, do: Application.get_env(:elixir_drops, :s3_helper, Http)
end
