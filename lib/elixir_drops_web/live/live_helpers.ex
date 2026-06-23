defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc """
  Shared `on_mount/4` hooks.

  These hooks run on the disconnected (dead) render and, with `:resume` enabled,
  their results are reused on the connected render rather than recomputed. They
  must therefore derive everything from data available on the dead render (the
  session, the current user) — never from `get_connect_params/1` or
  `get_connect_info/2`, which are only populated once connected.
  """

  import Phoenix.Component, only: [assign: 2]

  alias ElixirDropsWeb.NotificationHelpers

  @type socket :: Phoenix.LiveView.Socket.t()

  @doc """
  Assigns `:show_welcome_message?` from the `show_welcome_message` session value.

  The flag is carried in a cookie that `ElixirDropsWeb.Router`'s `:browser`
  pipeline copies into the session (see `put_welcome_message_flag/2`), so it is
  available on the dead render. Reading it here — instead of from
  `get_connect_params/1` — keeps the dead render authoritative and avoids the
  banner flashing in or out when the socket connects. First-time visitors (no
  cookie yet) default to seeing the welcome message.
  """
  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:maybe_show_welcome_message, _params, session, socket) do
    {:cont, assign(socket, show_welcome_message?: Map.get(session, "show_welcome_message", true))}
  end

  # Loads the current user's notifications on the dead render. Under :resume the
  # connected render reuses this result, so the work is done once and the value is
  # correct in the first paint (no connected?/1 guard, no placeholder that would
  # otherwise stick around on a resumed connect).
  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:assign_notifications, _params, _session, socket) do
    {:cont, NotificationHelpers.assign_notifications(socket)}
  end
end
