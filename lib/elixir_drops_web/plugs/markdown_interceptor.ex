defmodule ElixirDropsWeb.Plugs.MarkdownInterceptor do
  @moduledoc """
  Minimal interceptor that handles `.md` file extension requests for drops.

  Only intercepts requests matching `/d/:short_id.md` pattern and routes them
  to the MarkdownController. All other requests pass through unchanged.

  This is a focused solution to Phoenix's limitation of not supporting
  file extensions in dynamic route parameters.
  """

  import Plug.Conn

  alias Plug.Conn

  @type conn :: Conn.t()

  @spec init(any()) :: any()
  def init(opts), do: opts

  @spec call(conn(), any()) :: conn()
  def call(conn, _opts) do
    case conn.path_info do
      ["d", <<short_id::binary-size(8), ".md">>] ->
        # Binary pattern match for exactly 8 chars + ".md"
        conn
        |> put_resp_content_type("text/markdown")
        |> ElixirDropsWeb.MarkdownController.show(%{"short_id" => short_id})
        |> halt()

      _path ->
        # Pass through all other requests unchanged
        conn
    end
  end
end
