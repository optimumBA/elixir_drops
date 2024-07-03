defmodule ElixirDrops.Repo do
  use Ecto.Repo,
    otp_app: :elixir_drops,
    adapter: Ecto.Adapters.Postgres
end
