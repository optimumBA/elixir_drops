defmodule ElixirDropsWeb.HealthController do
  @moduledoc false

  use ElixirDropsWeb, :controller

  alias Ecto.Adapters.SQL

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @spec index(conn(), params()) :: conn()
  def index(conn, _params) do
    # Return status 500 if unable to connect to DB
    SQL.query!(ElixirDrops.Repo, "SELECT 1")

    {:ok, hostname} = :inet.gethostname()

    json(conn, %{
      connected_to: Node.list(),
      hostname: to_string(hostname),
      node: Node.self(),
      status: :ok
    })
  end
end
