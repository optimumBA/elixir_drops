defmodule ElixirDropsWeb.ScreenshotGeneratorController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @spec index(conn(), params()) :: conn()
  def index(conn, %{"id" => id}) do
    drop = Drops.get_drop(%{drop_id: id})

    case drop do
      %Drop{} ->
        case Regex.run(@markdown_regex, drop.body, capture: :first) do
          [code_block] ->
            render(conn, :index, code_block: code_block, layout: false)

          _no_code_block ->
            send_resp(conn, :not_found, "404 Not Found")
        end

      _drop_not_found ->
        send_resp(conn, :not_found, "404 Not Found")
    end
  end
end
