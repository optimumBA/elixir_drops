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
    with {:ok, user_params} <- user_info_from_auth(auth),
         github_token <- Map.get(auth.credentials, :token),
         {:ok, user} <- Accounts.get_or_create_user(user_params) do
      Accounts.clear_all_tokens_for_user(user)
      UserAuth.log_in_user(conn, user, github_token)
    else
      _error ->
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

  defp user_info_from_auth(%{info: info} = auth) when is_map(info) do
    {:ok,
     %{
       avatar: info.image,
       email: info.email,
       github_id: auth.uid,
       github_username: info.nickname,
       name: name_from_auth(auth)
     }}
  end

  defp user_info_from_auth(_auth), do: {:error, "Auth error"}

  defp name_from_auth(%{info: %{name: name}}) when is_binary(name), do: name

  defp name_from_auth(%{info: %{first_name: nil, last_name: nil, nicknane: nickname}}),
    do: nickname

  defp name_from_auth(auth) do
    auth
    |> Map.get(:info, %{})
    |> Map.take([:first_name, :last_name])
    |> Map.values()
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end
end
