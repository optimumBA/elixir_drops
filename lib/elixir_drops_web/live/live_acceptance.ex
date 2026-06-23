defmodule ElixirDropsWeb.LiveAcceptance do
  @moduledoc """
  Grants the connected LiveView process access to the Ecto SQL Sandbox in tests.

  A LiveView's connected process is separate from the test process that owns the
  sandbox connection, so it must be explicitly allowed. We cover both connect
  paths, because under `:resume` they run different lifecycle callbacks:

    * `on_mount/4` runs on the disconnected (dead) render and on a cold connect.
    * `allow_sandbox/1` is called from `c:Phoenix.LiveView.on_connect/1` (injected
      by `ElixirDropsWeb.live_view/0`), which is the only relevant callback that
      runs on a resumed (warm) connect, where `mount/3` and the on_mount hooks are
      skipped.

  The sandbox metadata travels in the `user-agent` header (see
  `ElixirDropsWeb.ConnCase`), so it is only available once connected.
  """

  @type socket :: Phoenix.LiveView.Socket.t()

  if Application.compile_env(:elixir_drops, :sql_sandbox) do
    import Phoenix.LiveView, only: [connected?: 1, get_connect_info: 2]

    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:default, _params, _session, socket) do
      if connected?(socket), do: allow(get_connect_info(socket, :user_agent))
      {:cont, socket}
    end

    @spec allow_sandbox(socket()) :: socket()
    def allow_sandbox(socket) do
      allow(get_connect_info(socket, :user_agent))
      socket
    end

    defp allow(nil), do: :ok

    defp allow(metadata) do
      Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)
    rescue
      # Connection already allowed — expected when both on_mount and on_connect run.
      DBConnection.OwnershipError -> :ok
    end
  else
    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:default, _params, _session, socket), do: {:cont, socket}

    @spec allow_sandbox(socket()) :: socket()
    def allow_sandbox(socket), do: socket
  end
end
