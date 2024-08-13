defmodule ElixirDropsWeb.SeoLiveTest do
  use ElixirDropsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "/:code_block" do
    test "renders page for seo image generation for a code block", %{conn: conn} do
      code_block = "```elixir\n1 + 1\n```"
      {:ok, _live, html} = live(conn, ~p"/seo/#{code_block}")

      assert html =~ ~r/<pre [^>]+>/
    end

    test "renders page for seo image generation for a code block with image", %{conn: conn} do
      code_block = "![image](https://example.com/image.png)"

      {:ok, _live, html} = live(conn, ~p"/seo/#{code_block}")

      assert html =~ ~r/<img [^>]+>/
      assert html =~ ~r/src="https:\/\/example.com\/image.png"/
    end
  end
end
