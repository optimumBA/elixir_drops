defmodule ElixirDrops.Comments.CommentsBroadcast do
  @moduledoc """
  Broadcasts comment events to subscribers.
  """

  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.PubSub

  @doc """
  Subscribes to comment events for a drop.
  """
  @spec subscribe(String.t()) :: :ok
  def subscribe(drop_id) do
    topic = topic(drop_id)
    Phoenix.PubSub.subscribe(PubSub, topic)
  end

  @doc """
  Broadcasts comment creation to all subscribers.
  """

  @spec broadcast_comment_creation(Comment.t()) :: :ok
  def broadcast_comment_creation(%Comment{} = comment) do
    topic = topic(comment.drop_id)

    Phoenix.PubSub.broadcast(
      PubSub,
      topic,
      {
        __MODULE__,
        :comment_created,
        comment
      }
    )
  end

  defp topic(drop_id), do: "drop_comments:#{drop_id}"
end
