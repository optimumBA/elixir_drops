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
    unique_id = System.unique_integer([:positive])

    {:ok, user} =
      attrs
      |> Enum.into(%{
        avatar: "https://avatars.githubusercontent.com/u/#{unique_id}?v=4",
        email: unique_user_email(),
        github_id: unique_id,
        github_username: "github_user_#{unique_id}",
        name: "User #{unique_id}"
      })
      |> Accounts.register_user()

    user
  end
end
