defmodule ElixirDrops.DropsBroadcast do
  @moduledoc """
  Broadcasts drop changes to all connected clients.
  """
  alias ElixirDrops.Drops.Drop
  @type short_unique_string :: String.t()
  @type drop :: Drop.t()
  @topic inspect(__MODULE__)

  @doc """
  Subscribes to drops events.

  ## Examples

    iex> subscribe()
    :ok

  """

  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(ElixirDrops.PubSub, @topic)
  end

  @doc """
  Broadcasts a message indicating that a new drop has been created.

  The message is broadcast on the `@topic` using Phoenix PubSub. Other processes that subscribe to this topic will receive the broadcast message.

  ## Parameters

    - `drop`: The drop data to be broadcast, typically a map or struct representing the newly created drop.

  ## Examples

      iex> broadcast_drop_creation(%{
      ...>   id: 1,
      ...>   title: "New Drop",
      ...>   body: "This is a new drop.",
      ...>   user_id: 1,
      ...>   unique_url_string: "abc123"
      ...> })
      :ok

  """
  @spec broadcast_drop_creation(drop()) :: :ok
  def broadcast_drop_creation(drop) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      @topic,
      {
        __MODULE__,
        [:drop, :created],
        drop
      }
    )
  end
end
