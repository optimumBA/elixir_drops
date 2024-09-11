defmodule ElixirDrops.DropsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Drops` context.
  """

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

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
      Drops.create_drop(drop, user, drop_attrs)

    drop
  end

  @doc """
  Updated a drop inserted at time
  """
  @spec update_drop_inserted_at(drop(), integer()) :: drop()
  def update_drop_inserted_at(drop, seconds_offset) do
    {:ok, updated_drop} =
      drop
      |> Ecto.Changeset.change(%{inserted_at: time_before_or_after(seconds_offset)})
      |> Repo.update()

    updated_drop
  end

  defp time_before_or_after(seconds_offset) do
    DateTime.utc_now()
    |> DateTime.add(seconds_offset)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end
end
