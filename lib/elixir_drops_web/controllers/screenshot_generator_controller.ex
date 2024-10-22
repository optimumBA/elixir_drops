defmodule ElixirDropsWeb.ScreenshotGeneratorController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @spec index(conn(), params()) :: conn()
  def index(conn, %{"id" => id}) do
    with %Drop{} = drop <- Drops.get_drop(%{drop_id: id}),
         [code_block] <- Regex.run(@markdown_regex, drop.body, capture: :first) do
      render(conn, :index, code_block: code_block, layout: false)
    else
      _no_code_block ->
        render(conn, :index, code_block: "No code block found", layout: false)
    end
  end
end
