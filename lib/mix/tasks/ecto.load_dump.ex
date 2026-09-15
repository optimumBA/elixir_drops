defmodule Mix.Tasks.Ecto.LoadDump do
  @shortdoc "Loads priv/repo/sanitized_data.dump when present"

  @moduledoc """
  Loads `priv/repo/sanitized_data.dump` into the development database when that
  file is present.

  No dump is distributed with the source. `mix setup` skips this step when the
  file is absent and continues with migrations and seeds, so a first run starts
  from an empty database. Maintainers generate a dump with
  `priv/repo/sanitize_prod_data.exs` and keep it out of version control.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Ensure the application and repo are started
    Mix.Task.run("app.start")

    dump_path = "priv/repo/sanitized_data.dump"

    cond do
      not File.exists?(dump_path) ->
        Mix.shell().info("ℹ️  No sanitized dump found, skipping...")

      database_has_data?() ->
        Mix.shell().info("ℹ️  Database already has data, skipping dump load...")

      true ->
        load_dump(dump_path)
    end
  end

  defp load_dump(dump_path) do
    # Check if pg_restore is available
    case System.cmd("which", ["pg_restore"], env: [], stderr_to_stdout: true) do
      {_path, 0} ->
        # pg_restore is available, proceed with loading
        do_load_dump(dump_path)

      {_output, _exit_code} ->
        Mix.shell().info("⚠️  pg_restore not found - PostgreSQL client tools not installed")
        Mix.shell().info("ℹ️  Skipping dump load, will use seeds instead")
    end
  end

  defp do_load_dump(dump_path) do
    Mix.shell().info("🗃️  Loading sanitized dump...")

    # Get database name from config
    config = Application.get_env(:elixir_drops, ElixirDrops.Repo)
    database = config[:database]

    # Load the dump using pg_restore
    case System.cmd(
           "pg_restore",
           [
             "--dbname=#{database}",
             "--username=#{config[:username]}",
             "--host=#{config[:hostname]}",
             "--no-owner",
             "--no-privileges",
             "--clean",
             "--if-exists",
             dump_path
           ],
           stderr_to_stdout: true,
           env: [{"PGPASSWORD", config[:password]}]
         ) do
      {_output, 0} ->
        file_size =
          dump_path
          |> File.stat!()
          |> Map.get(:size)
          |> format_bytes()

        Mix.shell().info("✅ Successfully loaded sanitized dump (#{file_size})")

      {output, exit_code} ->
        Mix.raise("pg_restore failed with exit code #{exit_code}: #{output}")
    end
  end

  defp database_has_data? do
    case ElixirDrops.Repo.query("SELECT COUNT(*) FROM users", []) do
      {:ok, %{rows: [[0]]}} -> false
      {:ok, %{rows: [[_count]]}} -> true
      {:error, _error} -> false
    end
  rescue
    _error -> false
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end
end
