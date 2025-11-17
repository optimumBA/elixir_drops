[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [DoctestFormatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    ".github/github_workflows.ex",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/generate_sitemap.exs",
    "priv/*/seeds.exs",
    "priv/repo/sanitize_prod_data.exs"
  ]
]
