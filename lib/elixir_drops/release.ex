defmodule ElixirDrops.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """

  @type response :: {:ok, fun(), any()}

  @app :elixir_drops

  @doc """
  Migrates the production DB.
  """
  @spec migrate() :: [response()]
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _fun_return, _apps} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
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
        Ecto.Migrator.with_repo(repo, fn repo ->
          # Run the seed script if it exists
          seed_script = priv_path_for(repo, "seeds.exs")

          if File.exists?(seed_script) do
            Code.eval_file(seed_script)
          end
        end)
    end
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
      |> Enum.at(-2)
      |> Macro.underscore()

    priv_dir =
      app
      |> :code.priv_dir()
      |> to_string()

    Path.join([priv_dir, repo_underscore, filename])
  end
end
