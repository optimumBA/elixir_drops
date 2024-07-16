defmodule ElixirDropsWeb.GitAuthControllerTest do
  use ElixirDropsWeb.ConnCase, async: true

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Repo
  alias ElixirDropsWeb.GithubAuthController

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ElixirDropsWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn, user_token: "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"}
  end

  @ueberauth_auth %{
    credentials: %{token: "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"},
    info: %{
      avatar: "http://github.com/dano_csharp_avatar.jpg",
      email: "dano.csharp@gmail.com",
      first_name: "Tony",
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

  describe "get /auth/github/callback" do
    test "when token is invalid redirects to the root path", %{conn: conn} do
      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_failure, %{})
        |> fetch_flash()
        |> GithubAuthController.callback(%{})

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "User authentication failed!"
    end

    test "when user exists it logs them in", %{conn: conn} do
      user = user_fixture(github_id: 1234)
      ueberauth_auth = Map.put(@ueberauth_auth, :uid, 1234)

      assert Repo.aggregate(User, :count) == 1

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert Repo.aggregate(User, :count) == 1

      assert user_token = get_session(conn, :user_token)
      assert %User{} = current_user = Accounts.get_user_by_session_token(user_token)
      assert current_user.id == user.id
    end

    test "when user does not exist it creates a new user and logs them in", %{conn: conn} do
      assert Repo.aggregate(User, :count) == 0

      conn =
        conn
        |> bypass_through(ElixirDropsWeb.Router, [:browser])
        |> assign(:ueberauth_auth, @ueberauth_auth)
        |> GithubAuthController.callback(%{})

      assert Repo.aggregate(User, :count) == 1

      assert user_token = get_session(conn, :user_token)
      assert %User{} = Accounts.get_user_by_session_token(user_token)
    end

    test "when user is not valid it returns an error", %{conn: conn} do
      assert Repo.aggregate(User, :count) == 0

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
      assert Repo.aggregate(User, :count) == 0
    end
  end

  test "logout clears the session", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{user_token: "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"})
      |> get(~p"/auth/logout")

    refute get_session(conn, :user_token)
  end

  test "logout redirects to /", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{user_token: "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"})
      |> get(~p"/auth/logout")

    assert redirected_to(conn, 302)
    %{resp_headers: headers} = conn
    location = Enum.at(headers, length(headers) - 1)
    {_loc, value} = location
    assert value == "/"

    assert redirected_to(conn, 302)
  end
end
