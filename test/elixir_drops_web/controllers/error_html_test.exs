defmodule ElixirDropsWeb.ErrorHTMLTest do
  use ElixirDropsWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  describe "render/2" do
    test "404.html renders a complete document with a heading and recovery links" do
      html = render_to_string(ElixirDropsWeb.ErrorHTML, "404", "html", [])

      assert html =~ "<!DOCTYPE html>"
      assert html =~ ~s(href="/assets/css/app.css")
      assert html =~ ~r/<h1[^>]*>\s*Page not found\s*<\/h1>/
      assert html =~ ~s(href="/")
      assert html =~ ~s(href="/archive")
      refute html =~ "/privacy"
      refute html =~ "/terms"
    end

    test "an unknown path keeps HTTP 404 with the site-consistent body", %{conn: conn} do
      conn = get(conn, "/this-page-does-not-exist")

      body = html_response(conn, 404)
      assert conn.status == 404
      assert body =~ "Page not found"
      assert body =~ ~s(href="/archive")
    end
  end

  test "renders 500.html" do
    assert render_to_string(ElixirDropsWeb.ErrorHTML, "500", "html", []) ==
             "Internal Server Error"
  end
end
