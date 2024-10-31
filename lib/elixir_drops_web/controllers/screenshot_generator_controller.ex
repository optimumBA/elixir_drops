defmodule ElixirDropsWeb.ScreenshotGeneratorController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  require Logger

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @spec index(conn(), params()) :: conn()
  def index(conn, %{"id" => id}) do
    case authenticate(conn) do
      :ok ->
        handle_drop_retrieval(conn, id)

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

  defp handle_drop_retrieval(conn, id) do
    case Drops.get_drop(%{drop_id: id}) do
      %Drop{body: body} ->
        case Regex.run(@markdown_regex, body, capture: :first) do
          [code_block] ->
            render(conn, :index, code_block: code_block, layout: false)

          _no_code_block ->
            send_resp(conn, :not_found, "404 Not Found")
        end

      _drop_not_found ->
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
