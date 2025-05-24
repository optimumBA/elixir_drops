defmodule ElixirDropsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ElixirDropsWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User

  @type conn :: Plug.Conn.t()
  @type context :: map()
  @type user :: User.t()

  using do
    quote do
      # The default endpoint for testing
      @endpoint ElixirDropsWeb.Endpoint

      use ElixirDropsWeb, :verified_routes
      use Oban.Testing, repo: ElixirDrops.Repo

      # Import conveniences for testing with connections
      import ElixirDropsWeb.ConnCase
      import Phoenix.ConnTest
      import Plug.Conn
    end
  end

  setup tags do
    ElixirDrops.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that logs in users.

  setup :sign_in_user

  Returns an updated conn.
  """
  @spec sign_in_user(conn(), user()) :: conn()
  def sign_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{user_token: token})
      |> Plug.Conn.put_session(:user_token, token)

    conn
  end
end
