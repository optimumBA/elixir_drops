defmodule ElixirDropsWeb.GithubAuthControllerTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Repo
  alias ElixirDropsWeb.GithubAuthController

  @valid_test_user_token "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"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ElixirDropsWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn, user_token: @valid_test_user_token}
  end

  @ueberauth_auth %{
    credentials: %{token: "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"},
    info: %{
      email: "dano.csharp@gmail.com",
      first_name: "Tony",
      image: "https://avatars.githubusercontent.com/u/1456872?v=4",
      last_name: "Picula",
      name: nil,
      nickname: "DohaoTz4",
      urls: %{
        html_url: "https://github.com/DohaoTz4"
      }
    },
    provider: :github,
    uid: 61_067_389
  }

  describe "GET /auth/github/callback" do
    test "when token is invalid redirects to the root path", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_failure, %{})
        |> fetch_flash()
        |> GithubAuthController.callback(%{})

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "GitHub sign-in did not complete. Try signing in again."
    end

    test "when user exists it logs them in", %{conn: conn} do
      user = user_fixture(github_id: 1234)
      ueberauth_auth = Map.put(@ueberauth_auth, :uid, 1234)

      initial_count = Repo.aggregate(User, :count)

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert Repo.aggregate(User, :count) == initial_count

      assert user_token = get_session(conn, :user_token)
      assert %User{} = current_user = Accounts.get_user_by_session_token(user_token)
      assert current_user.id == user.id
    end

    test "when user does not exist it creates a new user and logs them in", %{conn: conn} do
      initial_count = Repo.aggregate(User, :count)

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, @ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert Repo.aggregate(User, :count) == initial_count + 1

      assert user_token = get_session(conn, :user_token)
      assert %User{} = user = Accounts.get_user_by_session_token(user_token)
      assert user.name == "Tony Picula"
    end

    test "when user is not valid it returns an error", %{conn: conn} do
      initial_count = Repo.aggregate(User, :count)

      ueberauth_auth =
        @ueberauth_auth
        |> update_in([:info, :first_name], fn _value -> "" end)
        |> update_in([:info, :last_name], fn _value -> "" end)
        |> update_in([:info, :nickname], fn _value -> "" end)

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert redirected_to(conn, 302)
      assert Repo.aggregate(User, :count) == initial_count
    end

    test "returns error when auth.info in invalid", %{conn: conn} do
      initial_count = Repo.aggregate(User, :count)
      ueberauth_auth = Map.put(@ueberauth_auth, :info, nil)

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert redirected_to(conn, 302)
      assert Repo.aggregate(User, :count) == initial_count
    end

    test "extracts user name from auth", %{conn: conn} do
      ueberauth_auth =
        update_in(
          @ueberauth_auth,
          [:info, :name],
          fn _value -> "Tony Picula" end
        )

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert user_token = get_session(conn, :user_token)
      assert %User{} = user = Accounts.get_user_by_session_token(user_token)
      assert user.name == "Tony Picula"
    end

    test "uses nickname as name if name is not present", %{conn: conn} do
      ueberauth_auth =
        @ueberauth_auth
        |> update_in([:info, :name], fn _value -> nil end)
        |> update_in([:info, :first_name], fn _value -> nil end)
        |> update_in([:info, :last_name], fn _value -> nil end)

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert user_token = get_session(conn, :user_token)
      assert %User{} = user = Accounts.get_user_by_session_token(user_token)
      assert user.name == "DohaoTz4"
    end
  end

  describe "GET /auth/logout" do
    @describetag error_path_exemption:
                   "Logout clears the session and redirects even when no session is present."

    test "clears the session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_token: @valid_test_user_token})
        |> get(~p"/auth/logout")

      refute get_session(conn, :user_token)
    end

    test "redirects to /", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_token: @valid_test_user_token})
        |> get(~p"/auth/logout")

      assert redirected_to(conn, 302)
      %{resp_headers: headers} = conn
      location = Enum.at(headers, length(headers) - 1)
      {_loc, value} = location
      assert value == "/"

      assert redirected_to(conn, 302)
    end
  end

  describe "GET /auth/:provider (unsupported)" do
    @describetag error_path_exemption:
                   "Unsupported providers are not routed, so no controller or database work runs."

    @unsupported_providers ["google", "login", "not-a-provider"]

    test "initiate paths answer 404", %{conn: conn} do
      for provider <- @unsupported_providers do
        conn = get(conn, "/auth/#{provider}")
        assert html_response(conn, 404), "GET /auth/#{provider}"
      end
    end

    test "callback paths answer 404", %{conn: conn} do
      for provider <- @unsupported_providers do
        conn = get(conn, "/auth/#{provider}/callback")
        assert html_response(conn, 404), "GET /auth/#{provider}/callback"
      end
    end

    test "the router does not dispatch them" do
      for provider <- @unsupported_providers, suffix <- ["", "/callback"] do
        assert Phoenix.Router.route_info(
                 ElixirDropsWeb.Router,
                 "GET",
                 "/auth/#{provider}#{suffix}",
                 ""
               ) == :error
      end
    end
  end

  describe "GET /auth/github" do
    setup do
      previous = Application.fetch_env(:ueberauth, Ueberauth.Strategy.Github.OAuth)

      Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth,
        client_id: "test-client-id",
        client_secret: "test-client-secret"
      )

      on_exit(fn ->
        case previous do
          {:ok, value} ->
            Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth, value)

          :error ->
            Application.delete_env(:ueberauth, Ueberauth.Strategy.Github.OAuth)
        end
      end)
    end

    test "redirects to github.com and keeps return_to", %{conn: conn} do
      conn = get(conn, "/auth/github?return_to=%2Fd%2Fabc")

      assert redirected_to(conn, 302) =~ "https://github.com/login/oauth/authorize"
      assert get_session(conn, :user_return_to) == "/d/abc"
    end
  end

  describe "GET /auth routes" do
    test "are exactly logout plus the configured providers" do
      auth_paths =
        ElixirDropsWeb.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&(&1.plug == GithubAuthController and &1.verb == :get))
        |> Enum.map(& &1.path)
        |> Enum.sort()

      providers =
        :ueberauth
        |> Application.fetch_env!(Ueberauth)
        |> Keyword.fetch!(:providers)
        |> Keyword.keys()

      expected =
        ["/auth/logout"] ++
          Enum.flat_map(providers, &["/auth/#{&1}", "/auth/#{&1}/callback"])

      assert auth_paths == Enum.sort(expected)
      assert auth_paths == ["/auth/github", "/auth/github/callback", "/auth/logout"]
    end
  end
end
