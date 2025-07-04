defmodule ElixirDrops.Comments.Comment do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Comments.MarkdownRenderer
  alias ElixirDrops.Drops.Drop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "comments" do
    field :body, :string
    field :body_html, :string
    field :deleted_at, :utc_datetime_usec
    field :edited_at, :utc_datetime_usec

    belongs_to :drop, Drop
    belongs_to :parent, Comment
    belongs_to :user, User

    has_many :replies, Comment, foreign_key: :parent_id

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :drop_id, :parent_id, :user_id])
    |> validate_required([:body, :drop_id, :user_id])
    |> validate_length(:body, min: 1, max: 1000)
    |> validate_parent_depth()
    |> put_body_html()
  end

  @spec edit_changeset(t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 1000)
    |> put_body_html()
    |> put_change(:edited_at, DateTime.utc_now())
  end

  defp validate_parent_depth(changeset) do
    case get_change(changeset, :parent_id) do
      nil ->
        changeset

      parent_id ->
        parent = ElixirDrops.Repo.get(Comment, parent_id)

        if parent && parent.parent_id do
          add_error(changeset, :parent_id, "replies cannot have replies")
        else
          changeset
        end
    end
  end

  defp put_body_html(changeset) do
    case get_change(changeset, :body) do
      nil ->
        changeset

      body ->
        body_html = MarkdownRenderer.render(body)
        put_change(changeset, :body_html, body_html)
    end
  end
end
