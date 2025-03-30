defmodule ElixirDrops.Drops.DropsBroadcast do
  @moduledoc """
  Broadcasts drop changes to all connected clients.
  """

  alias ElixirDrops.Drops.Drop

  @type drop :: Drop.t()
  @type progress :: number()
  @type short_id_string :: String.t()
  @type status :: atom()

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
      ...>   short_id: "abc123"
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

  @doc """
  Broadcasts a message indicating the progress of a drop's screenshot generation.

  The message is broadcast on the `@topic` using Phoenix PubSub. Other processes that subscribe to this topic will receive the broadcast message.

  ## Parameters

    - `drop`: The drop data to be broadcast, typically a map or struct representing the drop.
    - `progress`: The progress of the screenshot generation, typically a number between 0 and 100.
    - `status`: The status of the screenshot generation, typically a string.

  ## Examples

      iex> broadcast_drop_screenshot_progress(
      ...>   %{
      ...>     id: 1,
      ...>     title: "New Drop",
      ...>     body: "This is a new drop.",
      ...>     user_id: 1,
      ...>     short_id: "abc123"
      ...>   },
      ...>   50,
      ...>   :generating
      ...> )
      :ok

  """
  @spec broadcast_drop_screenshot_progress(drop(), progress(), status()) :: :ok
  def broadcast_drop_screenshot_progress(drop, progress, status) do
    Phoenix.PubSub.broadcast(
      ElixirDrops.PubSub,
      @topic,
      {__MODULE__, [:drop, :screenshot_generation_progress], drop, progress, status}
    )
  end
end
