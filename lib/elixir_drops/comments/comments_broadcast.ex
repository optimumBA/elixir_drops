defmodule ElixirDrops.Comments.CommentsBroadcast do
  @moduledoc """
  Broadcasts comment events to subscribers.
  """

  alias ElixirDrops.Comments.Comment
  alias ElixirDropsWeb.Endpoint

  @doc """
  Subscribes to comment events for a drop.
  """
  @spec subscribe_to_drop(String.t()) :: :ok
  def subscribe_to_drop(drop_id) do
    drop_id
    |> topic()
    |> Endpoint.subscribe()
  end

  @doc """
  Broadcasts a comment event to all subscribers.
  """
  @spec broadcast_comment_event(Comment.t(), atom()) :: :ok
  def broadcast_comment_event(%Comment{} = comment, event) do
    comment.drop_id
    |> topic()
    |> Endpoint.broadcast("comment_event", %{event: event, comment: comment})
  end

  defp topic(drop_id), do: "drop_comments:#{drop_id}"
end
