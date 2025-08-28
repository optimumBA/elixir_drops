Mox.defmock(ElixirDrops.S3Helper.Client.Mock, for: ElixirDrops.S3Helper.Client)
Application.put_env(:elixir_drops, :s3_helper, ElixirDrops.S3Helper.Client.Mock)

ExUnit.start(exclude: [:feature])
Ecto.Adapters.SQL.Sandbox.mode(ElixirDrops.Repo, :manual)

Application.put_env(:phoenix_test, :base_url, ElixirDropsWeb.Endpoint.url())
