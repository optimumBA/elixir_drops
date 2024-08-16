defmodule ElixirDropsWeb.SeoLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "/:code_block" do
    test "renders page for seo image generation for a code block", %{conn: conn} do
      auth = Application.get_env(:elixir_drops, :wallaby_auth)
      header_content = "Basic " <> Base.encode64("#{auth[:username]}:#{auth[:password]}")

      conn = put_req_header(conn, "authorization", header_content)

      code_block = "```elixir\n1 + 1\n```"

      {:ok, _live, html} = live(conn, ~p"/seo/#{code_block}")

      assert html =~ ~r/<pre [^>]+>/
    end
  end
end
