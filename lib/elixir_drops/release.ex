defmodule ElixirDrops.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """

  alias ElixirDrops.Workers.SitemapGeneratorWorker

  @type response :: {:ok, fun(), any()}

  @app :elixir_drops

  @doc """
  Migrates the production DB.
  If database is empty and Tigris credentials are available, restores sanitized dump first.
  """
  @spec migrate() :: [response()]
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _fun_return, _apps} =
        Ecto.Migrator.with_repo(repo, &migrate_repo/1)
    end
  end

  @doc """
  Rolls back the production DB.
  """
  @spec rollback(Ecto.Repo.t(), any()) :: response()
  def rollback(repo, version) do
    load_app()

    {:ok, _fun_return, _apps} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds the production DB.
  """
  @spec seed() :: [response()]
  def seed do
    load_app()
    Application.ensure_all_started(@app)

    for repo <- repos() do
      {:ok, _fun_return, _apps} =
        Ecto.Migrator.with_repo(repo, &seed_repo/1)
    end
  end

  @doc """
  Enqueues sitemap generation job.
  This ensures the sitemap is available after deployment on ephemeral filesystems.
  """
  @spec generate_sitemap() :: :ok | {:error, String.t()}
  def generate_sitemap do
    load_app()
    Application.ensure_all_started(@app)

    %{}
    |> SitemapGeneratorWorker.new(schedule_in: 60)
    |> Oban.insert()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> Enum.at(-1)
      |> Macro.underscore()

    priv_dir =
      app
      |> :code.priv_dir()
      |> to_string()

    Path.join([priv_dir, repo_underscore, filename])
  end

  # Check if we should restore sanitized dump
  defp should_restore_sanitized_dump?(repo) do
    has_s3_config?() and database_is_empty?(repo)
  end

  # Check if S3 configuration is available
  defp has_s3_config? do
    not is_nil(System.get_env("AWS_ACCESS_KEY_ID")) and
      not is_nil(System.get_env("AWS_SECRET_ACCESS_KEY")) and
      not is_nil(System.get_env("BUCKET_NAME")) and
      not is_nil(System.get_env("DATABASE_DUMP_FILE"))
  end

  # Check if database has any application tables
  defp database_is_empty?(repo) do
    # Try to query the users table - if it doesn't exist or has no records, we need to restore
    case repo.query("SELECT COUNT(*) FROM users", []) do
      # Table exists but empty
      {:ok, %{rows: [[0]]}} -> true
      # Table has data
      {:ok, %{rows: [[_count]]}} -> false
      # Table doesn't exist
      {:error, _error} -> true
    end
  rescue
    # Any error means we should restore
    _error -> true
  end

  # Restore sanitized dump from Tigris
  defp restore_sanitized_dump(repo) do
    database_url = get_database_url(repo)
    {bucket, dump_file, temp_file} = get_dump_config()

    try do
      download_dump_from_tigris(bucket, dump_file, temp_file)
      restore_dump_to_database(temp_file, database_url)
    after
      File.rm(temp_file)
    end
  end

  defp get_database_url(repo) do
    database_url = repo.config()[:url] || System.get_env("DATABASE_URL")

    if !database_url do
      raise "DATABASE_URL not configured"
    end

    database_url
  end

  defp get_dump_config do
    bucket = System.get_env("BUCKET_NAME")
    dump_file = System.get_env("DATABASE_DUMP_FILE")
    temp_file = "/tmp/#{dump_file}"

    {bucket, dump_file, temp_file}
  end

  defp download_dump_from_tigris(bucket, dump_file, temp_file) do
    download_cmd = [
      "s3",
      "cp",
      "s3://#{bucket}/_db/#{dump_file}",
      temp_file,
      "--endpoint-url",
      System.get_env("AWS_ENDPOINT_URL_S3")
    ]

    case System.cmd("aws", download_cmd, stderr_to_stdout: true, env: []) do
      {_output, 0} -> :ok
      {error, exit_code} -> raise "Failed to download dump: #{error} (exit code: #{exit_code})"
    end
  end

  defp restore_dump_to_database(temp_file, database_url) do
    priv_dir =
      @app
      |> :code.priv_dir()
      |> to_string()

    restore_script_path = Path.join([priv_dir, "repo", "restore_sanitized_dump.sh"])

    case System.cmd("bash", [restore_script_path, temp_file, database_url],
           stderr_to_stdout: true,
           env: []
         ) do
      {_output, 0} -> :ok
      {error, exit_code} -> raise "Failed to restore dump: #{error} (exit code: #{exit_code})"
    end
  end

  defp migrate_repo(repo) do
    # Check if database has application tables
    if should_restore_sanitized_dump?(repo) do
      restore_sanitized_dump(repo)
    end

    # Run normal migrations
    Ecto.Migrator.run(repo, :up, all: true)
  end

  defp seed_repo(repo) do
    # Run the seed script if it exists
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      Code.eval_file(seed_script)
    end
  end
end
