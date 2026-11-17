defmodule ElixirDropsWeb.UnsupportedOauthProvidersReturnNotFoundTest do
  use ElixirDropsWeb.ConnCase, async: false

  alias ElixirDropsWeb.GithubAuthController

  @unsupported ["login", "google", "not-a-provider"]
  @router_path "lib/elixir_drops_web/router.ex"

  setup_all do
    previous = Application.fetch_env(:ueberauth, Ueberauth.Strategy.Github.OAuth)

    Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth,
      client_id: "test-client-id",
      client_secret: "test-client-secret"
    )

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth, value)
        :error -> Application.delete_env(:ueberauth, Ueberauth.Strategy.Github.OAuth)
      end
    end)

    :ok
  end

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ElixirDropsWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn}
  end

  defp configured_providers do
    :ueberauth |> Application.fetch_env!(Ueberauth) |> Keyword.fetch!(:providers) |> Keyword.keys()
  end

  test "unsupported initiate paths answer 404 without raising", %{conn: conn} do
    for provider <- @unsupported do
      conn = get(conn, "/auth/#{provider}")
      assert html_response(conn, 404) =~ "Page not found", "GET /auth/#{provider}"
    end
  end

  test "unsupported callback paths answer 404 without raising", %{conn: conn} do
    for provider <- @unsupported do
      conn = get(conn, "/auth/#{provider}/callback")
      assert html_response(conn, 404) =~ "Page not found", "GET /auth/#{provider}/callback"
    end
  end

  test "the router does not dispatch unsupported providers", %{conn: _conn} do
    for provider <- @unsupported, suffix <- ["", "/callback"] do
      path = "/auth/#{provider}#{suffix}"

      assert Phoenix.Router.route_info(ElixirDropsWeb.Router, "GET", path, "") == :error,
             "router dispatches GET #{path}"
    end
  end

  test "GitHub initiate redirects to github.com and keeps return_to", %{conn: conn} do
    conn = get(conn, "/auth/github?return_to=%2Fd%2Fabc")
    assert redirected_to(conn, 302) =~ "https://github.com/login/oauth/authorize"
    assert get_session(conn, :user_return_to) == "/d/abc"
  end

  test "GitHub callback failure keeps its redirect and flash", %{conn: conn} do
    conn = get(conn, "/auth/github/callback")
    assert redirected_to(conn, 302) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "GitHub sign-in did not complete. Try signing in again."
  end

  test "the auth routes come from the Ueberauth configuration", %{conn: _conn} do
    auth_get_paths =
      ElixirDropsWeb.Router
      |> Phoenix.Router.routes()
      |> Enum.filter(&(&1.plug == GithubAuthController and &1.verb == :get))
      |> Enum.map(& &1.path)

    assert "/auth/logout" in auth_get_paths

    expected =
      Enum.flat_map(configured_providers(), fn name ->
        ["/auth/#{name}", "/auth/#{name}/callback"]
      end)

    assert Enum.sort(List.delete(auth_get_paths, "/auth/logout")) == Enum.sort(expected)

    source = File.read!(@router_path)
    assert [scope] = Regex.run(~r/scope "\/auth".*?\n  end\n/s, source)
    refute String.replace(scope, "GithubAuthController", "") =~ ~r/github/i
  end
end
