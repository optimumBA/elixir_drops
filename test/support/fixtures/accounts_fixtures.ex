defmodule ElixirDrops.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Accounts` context.
  """

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User

  @doc """
  Generate a unique user email.
  """
  @spec unique_user_email() :: String.t()
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  @doc """
  Generate a user.
  """
  @spec user_fixture(map()) :: User.t()
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
        email: unique_user_email(),
        github_id: System.unique_integer([:positive]),
        github_username: "user#{System.unique_integer([:positive])}",
        name: "some_name"
      })
      |> Accounts.register_user()

    user
  end
end
