defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc """
  Shared `on_mount/4` hooks.

  These hooks run on the disconnected (dead) render and, with `:resume` enabled,
  their results are reused on the connected render rather than recomputed. They
  must therefore derive everything from data available on the dead render (the
  session, the current user) — never from `get_connect_params/1` or
  `get_connect_info/2`, which are only populated once connected.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, stream: 4]

  alias ElixirDrops.Notifications
  alias ElixirDropsWeb.BookmarkEvents
  alias ElixirDropsWeb.DropsBatchCalculator
  alias ElixirDropsWeb.DropsListHelper

  alias ElixirDropsWeb.NotificationHelpers

  @feed_views [
    ElixirDropsWeb.DropLive.Index,
    ElixirDropsWeb.DropLive.Show,
    ElixirDropsWeb.UserDropLive.Index,
    ElixirDropsWeb.ProfileLive.Show,
    ElixirDropsWeb.BookmarkLive.Index
  ]

  @type hook :: atom()
  @type params :: map()
  @type session :: map()
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
  @spec on_mount(hook(), params(), session(), socket()) :: {:cont, socket()}
  def on_mount(:maybe_show_welcome_message, _params, session, socket) do
    {:cont,
     assign(socket, :show_welcome_message?, Map.get(session, "show_welcome_message", true))}
  end

  # Loads the current user's notifications on the dead render. Under :resume the
  # connected render reuses this result, so the work is done once and the value is
  # correct in the first paint (no connected?/1 guard, no placeholder that would
  # otherwise stick around on a resumed connect).
  @spec on_mount(hook(), params(), session(), socket()) :: {:cont, socket()}
  def on_mount(:assign_notifications, _params, _session, socket) do
    assigned_socket = NotificationHelpers.assign_notifications(socket)

    if assigned_socket.view in @feed_views do
      {:cont,
       attach_hook(assigned_socket, :shared_page_events, :handle_event, &handle_shared_event/3)}
    else
      {:cont, assigned_socket}
    end
  end

  defp handle_shared_event(
         "mark_notifications_as_read",
         _params,
         %{assigns: %{current_user: user}} = socket
       ) do
    {_integer, nil} = Notifications.mark_all_as_read(user.id)

    {:halt,
     socket
     |> stream(:notifications, [], reset: true)
     |> assign(:notification_count, 0)}
  end

  defp handle_shared_event("update_viewport", %{"width" => width, "height" => height}, socket)
       when socket.view in [
              ElixirDropsWeb.DropLive.Index,
              ElixirDropsWeb.UserDropLive.Index,
              ElixirDropsWeb.ProfileLive.Show,
              ElixirDropsWeb.BookmarkLive.Index
            ] do
    batch_size = DropsBatchCalculator.calculate_batch_size(width, height)

    {:halt,
     socket
     |> assign(:batch_size, batch_size)
     |> assign(:viewport_height, height)
     |> assign(:viewport_width, width)}
  end

  defp handle_shared_event("load_more", _params, socket)
       when socket.view in [ElixirDropsWeb.DropLive.Index, ElixirDropsWeb.UserDropLive.Index] do
    loading_socket = assign(socket, :loading_more, true)

    {:noreply, updated_socket} =
      DropsListHelper.load_more(loading_socket, loading_socket.assigns.batch_size)

    {:halt, updated_socket}
  end

  # The one Bookmark action of every Drop card and of the Drop page. Only a
  # signed-in viewer saves anything; a visitor is prompted to sign in by the
  # control itself, so a stray event from one changes nothing.
  defp handle_shared_event(
         "toggle_bookmark",
         %{"drop_id" => drop_id, "saved" => saved?},
         %{assigns: %{current_user: %{id: user_id}}} = socket
       )
       when is_binary(drop_id) and is_boolean(saved?) do
    {:halt, BookmarkEvents.apply(socket, user_id, drop_id, saved?)}
  end

  defp handle_shared_event("toggle_bookmark", _params, socket), do: {:halt, socket}

  defp handle_shared_event(_event, _params, socket), do: {:cont, socket}
end
