defmodule ElixirDropsWeb.CodeSnippetController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.CodeSnippetHelper

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @code_block_pattern ~r/```(?:\w+\n)?(.+?)```/s
  @threshold 10

  @spec index(conn(), params()) :: conn()
  def index(conn, %{"id" => id} = params) do
    case authenticate(conn) do
      :ok ->
        type = Map.get(params, "type", "internal")
        handle_drop_retrieval(conn, id, type)

      :error ->
        request_auth(conn)
    end
  end

  defp authenticate(conn) do
    [username: username, password: password] = Application.get_env(:elixir_drops, :wallaby_auth)

    with {request_username, request_password} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- valid_username?(username, request_username),
         true <- valid_password?(password, request_password) do
      :ok
    else
      _invalid_auth -> :error
    end
  end

  defp handle_drop_retrieval(conn, id, type) do
    with %Drop{body: body} <- Drops.get_drop(%{drop_id: id}),
         [code_block] <- Regex.run(@code_block_pattern, body, capture: :first) do
      lines = CodeSnippetHelper.count_lines(code_block)

      small_window = lines < @threshold

      render(conn, :index,
        code_block: code_block,
        layout: false,
        small_window: small_window,
        type: type
      )
    else
      _error ->
        send_resp(conn, :not_found, "404 Not Found")
    end
  end

  defp request_auth(conn) do
    conn
    |> Plug.BasicAuth.request_basic_auth()
    |> halt()
  end

  defp valid_username?(username, request_username),
    do: Plug.Crypto.secure_compare(username, request_username)

  defp valid_password?(password, request_password),
    do: Plug.Crypto.secure_compare(password, request_password)
end
