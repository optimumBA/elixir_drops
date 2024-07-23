defmodule ElixirDrops.DropsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Drops` context.
  """

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @type drop :: Drop.t()
  @type user :: User.t()

  @doc """
  Generate a drop.
  """
  @spec drop_fixture(drop(), user(), map()) :: drop()
  def drop_fixture(drop \\ %Drop{}, %User{} = user, attrs \\ %{}) do
    random_string =
      12
      |> :crypto.strong_rand_bytes()
      |> Base.encode64()

    drop_title = "Drop title " <> random_string

    drop_attrs =
      Enum.into(attrs, %{
        body: "Drop body text...",
        title: drop_title
      })

    {:ok, drop} =
      Drops.create_or_update_drop(drop, user, drop_attrs)

    drop
  end
end
