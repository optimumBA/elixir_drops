defmodule ElixirDropsWeb.DevAuthController do
  @moduledoc """
  DEVELOPMENT ONLY - Remove before production
  Controller for bypassing authentication in development/testing
  """

  use ElixirDropsWeb, :controller

  alias ElixirDropsWeb.UserAuth

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @spec enable(conn(), params()) :: conn()
  def enable(conn, %{"user_id" => user_id} = _params) do
    if Application.get_env(:elixir_drops, :dev_auth_bypass, false) do
      user = ElixirDrops.Accounts.get_user!(user_id)
      UserAuth.log_in_user(conn, user)
    else
      conn
      |> put_status(:not_found)
      |> text("Not found")
    end
  end
end
