defmodule ElixirDropsWeb.LiveAcceptance do
  @moduledoc """
  LiveView acceptance testing hook for handling Ecto SQL Sandbox.

  Ensures all LiveView processes and their spawned children can access the 
  test database connection in async tests.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:default, _params, _session, socket) do
    socket =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    metadata = socket.assigns.phoenix_ecto_sandbox

    if metadata do
      setup_sandbox_access(metadata)
    end

    {:cont, socket}
  end

  defp setup_sandbox_access(metadata) do
    Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)
  rescue
    DBConnection.OwnershipError ->
      # Connection already allowed - this is expected in some test scenarios
      :ok
  end
end
