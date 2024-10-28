defmodule ElixirDropsWeb.ScreenshotGeneratorAuthPlug do
  @moduledoc false

  import Plug.Conn
  require Logger

  @spec init(any()) :: any()
  def init(options) do
    Logger.info(
      "Wallaby auth options: #{inspect(options ++ Application.get_env(:elixir_drops, :wallaby_auth))}"
    )

    options ++ Application.get_env(:elixir_drops, :wallaby_auth)
  end

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, options) do
    username = Keyword.fetch!(options, :username)
    password = Keyword.fetch!(options, :password)

    with {request_username, request_password} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <-
           valid_username?(username, request_username) and
             valid_password?(password, request_password) do
      conn
    else
      _invalid_auth ->
        conn
        |> Plug.BasicAuth.request_basic_auth()
        |> halt()
    end
  end

  defp valid_username?(username, request_username),
    do: Plug.Crypto.secure_compare(username, request_username)

  defp valid_password?(password, request_password),
    do: Plug.Crypto.secure_compare(password, request_password)
end
