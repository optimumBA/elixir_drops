defmodule ElixirDrops.Drops.Drop do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.DropTag
  alias ElixirDrops.Drops.Tag
  alias ElixirDrops.Repo

  @type changeset :: Ecto.Changeset.t()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "drops" do
    field :body, :string
    field :drop_tags, :string, virtual: true
    field :title, :string
    belongs_to :user, User
    many_to_many :tags, Tag, join_through: DropTag, on_replace: :delete, unique: true

    timestamps()
  end

  @spec changeset(t(), map()) :: changeset()
  def changeset(%__MODULE__{} = drop, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :drop_tags, :title])
    |> validate_required([:body, :drop_tags, :title])
  end

  @spec validate_tag_number(changeset(), atom(), Keyword.t()) :: changeset()
  def validate_tag_number(changeset, field, options \\ []) do
    validate_change(changeset, field, fn :drop_tags, drop_tags ->
      tags = parse_tags(drop_tags)

      if Enum.count(tags) in 2..10 do
        []
      else
        [{field, options[:message] || "Should have at least 2 drops and at most 10 tags"}]
      end
    end)
  end

  @spec check_and_update_tags(changeset(), map()) :: changeset()
  def check_and_update_tags(changeset, attrs) do
    if changeset.valid? do
      put_assoc(changeset, :tags, update_drop_tags(attrs))
    else
      changeset
    end
  end

  defp update_drop_tags(%{"drop_tags" => drop_tags}),
    do: update_drop_tags(%{drop_tags: drop_tags})

  defp update_drop_tags(%{drop_tags: drop_tags}) do
    drop_tags
    |> parse_tags()
    |> insert_or_update_tags()
  end

  defp update_drop_tags(_other), do: []

  defp parse_tags(drop_tags) do
    (drop_tags || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp insert_or_update_tags([]), do: []

  defp insert_or_update_tags(drop_tags) do
    for tag <- drop_tags do
      Repo.get_by(Tag, name: tag) || maybe_insert_tag(tag)
    end
  end

  defp maybe_insert_tag(tag) do
    %Tag{}
    |> Tag.changeset(%{name: tag})
    |> Repo.insert!(
      on_conflict: [set: [name: tag]],
      conflict_target: :name
    )
  end
end
