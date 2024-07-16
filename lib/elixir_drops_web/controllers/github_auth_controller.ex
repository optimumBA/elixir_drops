defmodule ElixirDropsWeb.GithubAuthController do
  @moduledoc """
  Github authentication controller.

  This controller implements the following Ueberauth methods and logout method:
   - callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params)
   - callback(%{assigns: %{assigns: %{ueberauth_auth: auth} = conn, _params)

  These methods are responsible for fetching user data from GitHub provider
  along with user token.

  """

  use ElixirDropsWeb, :controller

  plug Ueberauth

  import Plug.Conn

  alias ElixirDrops.Accounts
  alias ElixirDropsWeb.UserAuth

  @type conn :: Plug.Conn.t()
  @type params :: map()

  @doc """
  If the user authentication failes, it redirects to the return_to page or home page.
  When user successfully authenticates, it redirects the user to the return _to page or home page.
  """
  @spec callback(conn(), params()) :: conn()
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "User authentication failed!")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    {:ok, user_params} = user_info_from_auth(auth)

    github_token = auth.credentials.token

    case Accounts.get_or_create_user(user_params) do
      {:ok, user} ->
        Accounts.clear_all_tokens_for_user(user)
        UserAuth.log_in_user(conn, user, github_token)

      {:error, %Ecto.Changeset{} = _changeset} ->
        redirect(conn, to: ~p"/")
    end
  end

  @doc """
  Logs the user out, removes user token from cookie session and clear token record from db.
  """
  @spec logout(conn(), params()) :: conn()
  def logout(conn, _params) do
    UserAuth.log_out_user(conn)
  end

  defp user_info_from_auth(auth) do
    case Map.has_key?(auth, :info) do
      false ->
        {:error, "Auth error"}

      true ->
        {
          :ok,
          %{
            avatar: auth.info.image,
            github_id: auth.uid,
            github_username: auth.info.nickname,
            name: name_from_auth(auth),
            email: email_from_auth(auth)
          }
        }
    end
  end

  defp name_from_auth(auth) do
    if auth.info.name do
      auth.info.name
    else
      name =
        Enum.filter([auth.info.first_name, auth.info.last_name], fn name ->
          name != nil and name != ""
        end)

      if Enum.empty?(name) do
        auth.info.nickname
      else
        Enum.join(name, " ")
      end
    end
  end

  defp email_from_auth(%{info: %{email: email}}), do: email
end
