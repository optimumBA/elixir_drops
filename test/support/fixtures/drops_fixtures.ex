defmodule ElixirDrops.DropsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Drops` context.
  """

  import ElixirDrops.FactoryHelpers

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
        body: "Drop body text ```code block```...",
        screenshot: %{
          internal_url: nil,
          meta_url: nil,
          status: :completed
        },
        title: drop_title
      })

    {:ok, drop} =
      Drops.create_drop(drop, user, drop_attrs)

    drop
  end

  @spec create_multiple_drops(user(), integer()) :: list(drop())
  def create_multiple_drops(user, number_of_drops) do
    for drop <- 1..number_of_drops do
      offset_time = 120 * drop

      %Drop{}
      |> drop_fixture(user, %{
        body: "Body for drop #{drop}",
        screenshot: %{internal_url: nil, meta_url: nil, status: :completed},
        title: "Drop title #{drop}"
      })
      |> update_inserted_at(offset_time)
    end
  end
end
