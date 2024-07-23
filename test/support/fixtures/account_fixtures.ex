defmodule ElixirDrops.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Accounts` context.
  """

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Repo

  @doc """
  Generate a unique user email.
  """
  @spec unique_user_email() :: String.t()
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  # TODO: Replace when merged with auth

  @doc """
  Generate a user.
  """
  @spec user_fixture(map()) :: User.t()
  def user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
        email: unique_user_email(),
        github_id: 1_456_872,
        github_username: "github_username",
        name: "some_name"
      })

    {:ok, user} =
      %User{}
      |> Ecto.Changeset.change(attrs)
      |> Repo.insert()

    user
  end
end
