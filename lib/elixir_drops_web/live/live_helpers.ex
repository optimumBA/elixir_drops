defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc """
  LiveView helpers including database sandbox support for tests.

  Based on StoryDeck's proven async testing patterns.
  """

  import Phoenix.Component

  import Phoenix.LiveView,
    only: [attach_hook: 4, get_connect_params: 1, stream: 4, stream_insert: 4]

  alias ElixirDrops.Notifications
  alias ElixirDrops.Search
  alias ElixirDropsWeb.DropsBatchCalculator
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.NotificationHelpers
  alias ElixirDropsWeb.SearchHelper

  @type id :: Ecto.UUID.t()
  @type socket :: Phoenix.LiveView.Socket.t()

  # Existing welcome message functionality
  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:maybe_show_welcome_message, _params, _session, socket) do
    show_welcome_message =
      case get_connect_params(socket) do
        %{"show_welcome_message" => "true"} -> true
        _other -> false
      end

    {:cont, assign(socket, :show_welcome_message?, show_welcome_message)}
  end

  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:assign_notifications, _params, _session, socket) do
    {:cont, NotificationHelpers.assign_notifications(socket)}
  end

  def on_mount(:attach_shared_hooks, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:process_event, :handle_event, &process_event/3)
     |> attach_hook(:process_message, :handle_info, &process_message/2)}
  end

  # Only compile sandbox support in test environment
  if Application.compile_env(:elixir_drops, :sandbox, false) do
    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:allow_ecto_sandbox, _params, _session, socket) do
      # Get encoded metadata from process dictionary (set by FeatureCase)
      if encoded_metadata = Process.get(:phoenix_ecto_sandbox) do
        try do
          # Decode and allow this process to access the database
          metadata = Phoenix.Ecto.SQL.Sandbox.decode_metadata(encoded_metadata)
          # Correct API: Ecto.Adapters.SQL.Sandbox.allow(repo, owner_pid, allow_pid)
          # metadata contains {repo, owner_pid}, so we extract the owner and allow current process
          case metadata do
            {_repo, owner_pid} when is_pid(owner_pid) ->
              Ecto.Adapters.SQL.Sandbox.allow(ElixirDrops.Repo, owner_pid, self())

            _other ->
              :ok
          end
        rescue
          # If allow fails (e.g., already allowed), that's OK
          _error -> :ok
        end
      end

      {:cont, socket}
    end
  else
    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:allow_ecto_sandbox, _params, _session, socket), do: {:cont, socket}
  end

  # shared handle_event logic for Liveviews

  @spec update_viewport(non_neg_integer(), non_neg_integer(), socket()) :: socket()
  def update_viewport(width, height, socket) do
    batch_size = DropsBatchCalculator.calculate_batch_size(width, height)

    socket
    |> assign(:batch_size, batch_size)
    |> assign(:viewport_height, height)
    |> assign(:viewport_width, width)
  end

  defp process_event("load_more", _params, socket) do
    {:cont,
     socket
     |> assign(:loading_more, true)
     |> DropsListHelper.load_more(socket.assigns.batch_size)}
  end

  defp process_event("load_more_complete", _params, socket) do
    {:cont, assign(socket, :loading_more, false)}
  end

  defp process_event("load_more_notifications", _params, socket) do
    {:cont, NotificationHelpers.load_more(socket)}
  end

  defp process_event(
         "mark_notifications_as_read",
         _params,
         %{assigns: %{current_user: user}} = socket
       ) do
    {_integer, nil} = Notifications.mark_all_as_read(user.id)

    {:cont,
     socket
     |> stream(:notifications, [], reset: true)
     |> assign(:notification_count, 0)}
  end

  defp process_event("delete_search_history", %{"id" => id}, socket) do
    with %{current_user: %{id: user_id}} <- socket.assigns,
         {:ok, _} <- Search.delete_search_history(id, user_id) do
      # Re-fetch suggestions like focus does
      {suggestions, _} = SearchHelper.get_focus_search_suggestions(user_id)
      {:cont, assign(socket, :search_suggestions, suggestions)}
    else
      _error -> {:cont, socket}
    end
  end

  defp process_event(_event, _params, socket) do
    {:cont, socket}
  end

  defp process_message(
         {:new_notification, notification},
         %{assigns: %{notification_count: count}} = socket
       ) do
    {:cont,
     socket
     |> assign(:notification_count, count + 1)
     |> stream_insert(:notifications, notification, at: 0)}
  end

  defp process_message(_message, socket) do
    {:cont, socket}
  end
end
