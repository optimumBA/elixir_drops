# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ElixirDrops.Repo.insert!(%ElixirDrops.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ElixirDrops.Repo
alias ElixirDrops.Search.PopularSearch

initial_searches = [
  {"liveview", 20},
  {"oban", 19},
  {"phx.tools", 18},
  {"timex", 17},
  {"docker", 16},
  {"github actions", 15},
  {"tailwind", 14},
  {"memoize", 13},
  {"sitemap", 12},
  {"releases", 11},
  {"file upload", 10},
  {"seeds", 10},
  {"process messaging", 10},
  {"relative time", 10},
  {"io.inspect", 10}
]

for {query, count} <- initial_searches do
  Repo.insert!(
    %PopularSearch{
      query: query,
      search_count: count
    },
    on_conflict: :nothing,
    conflict_target: :query
  )
end
