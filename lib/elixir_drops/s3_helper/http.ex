defmodule ElixirDrops.S3Helper.Http do
  @moduledoc false

  @behaviour ElixirDrops.S3Helper.Client

  @impl ElixirDrops.S3Helper.Client
  def upload_image(image, filename, type, _retries \\ 0) do
    s3 = Application.fetch_env!(:elixir_drops, :s3)
    url = "#{s3[:endpoint_url]}/#{s3[:bucket]}/#{filename}"

    req =
      Req.new(
        aws_sigv4: [
          service: :s3,
          access_key_id: s3[:access_key_id],
          secret_access_key: s3[:secret_access_key]
        ],
        url: url,
        headers: [{"content-type", type}]
      )

    case Req.put(req, body: image) do
      {:ok, %{status: 200}} ->
        {:ok, url}

      {:error, error} ->
        {:error, error}
    end
  end
end
