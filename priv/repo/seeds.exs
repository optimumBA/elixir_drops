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
alias ElixirDrops.Accounts.User
alias ElixirDrops.Drops
alias ElixirDrops.Drops.Drop
alias ElixirDrops.Repo

drop_1_body = ~S"""
Today I learned that you can pass a version-file option to the erlef/setup-beam GitHub action to get the Elixir and OTP version in your pipeline from a file, e.g. a .tool-versions.

  I previously wrote my own custom pipeline step for this.

  ```yaml
  jobs:
    test:
      steps:
        - uses: actions/checkout@v4

        - uses: erlef/setup-beam@v1
          id: beam
          with:
            version-file: .tool-versions
            version-type: strict
  ```
  ---

  https://x.com/flo_arens/status/1805255159460532602
"""

drop_2_body = ~S"""
🤓 ELIXIR PRO TIP

If the latest version of a package is broken, and you want to pin it to a version that works, it is nice to specify that you do want the next version after that.

Saves wondering later why that version is pinned.

```elixir
defp deps do
  [
    # version 2.38.0 is broken
    {:ex_cldr, "== 2.37.5 or ~> 2.38.1 or ~> 2.39"}
  ]
end
```
---
https://x.com/derekkraan/status/1782676774461014219
"""

drop_3_body = ~S"""
In case you need to wait for a longer period in a specific feature, but still want the other feature tests to wait for a shorter period, you can add the following function to your `FeatureCase` module:

```elixir
def with_timeout(session, timeout, callback, started_at \\ NaiveDateTime.utc_now()) do
  callback.(session)
rescue
  exception in Wallaby.ExpectationNotMetError ->
    if NaiveDateTime.compare(
        NaiveDateTime.utc_now(),
        NaiveDateTime.add(started_at, timeout, :millisecond)
      ) == :gt do
      reraise exception, __STACKTRACE__
    else
      with_timeout(session, timeout, callback, started_at)
    end

  exception ->
    reraise exception, __STACKTRACE__
end
```

and use it like this:
```elixir
feature "user uploads large file", %{session: session, story: story} do
  session
  |> visit(~p"/stories/#{story_id}")
  |> click(Query.css(".assets-section-link"))
  |> assert_text("Story Assets")
  |> attach_file(Query.css(".asset-input", visible: false),
    path: "test/support/fixtures/files/mux_extended.mov"
  )
  |> assert_text("mux_extended.mov")
  |> assert_text(
    "Upload in progress (0 / 1 file(s) completed). Please don't close story window."
  )
  |> with_timeout(120_000, fn session ->
    lazily_refute_has(session, Query.css(".asset-progress-container"))
  end)
  |> lazily_refute_has(
    Query.text("Upload in progress (0 / 1 file(s) completed). Please don't close story window.")
  )
end
```
Of course, you'll probably need to add `@tag timeout: 150_000` to prevent ExUnit from timing out.
"""

drop_4_body = ~S"""
When using `refute_has/2` in Wallaby tests, Wallaby waits for the specified `max_wait_time`, 3 seconds by default.

There is a better way to check that an element becomes/is hidden.

Add the following function to your `FeatureCase` module:

```elixir
def lazily_refute_has(session, %Query{} = query) do
  conditions = Keyword.put(query.conditions, :count, 0)
  assert_has(session, %Query{query | conditions: conditions})
end
```

and you'll be able to refute the existence of an element without waiting.

```elixir
session
|> assert_text("Take a moment to finalize your profile")
|> click(Query.css("#profile-form-button"))
|> lazily_refute_has(Query.text("Take a moment to finalize your profile"))
```

In case an element is supposed to disappear only after some action takes place, Wallaby will wait for the configured amount of time (`max_wait_time`). If it still appears after those 3 seconds, the test will fail.
"""

drop_5_body = ~S"""
You can easily enable the automatic setting of a new AppSignal revision every time you commit and deploy your application.

First, make sure Docker doesn't ignore necessary git files.
Add this to your `.dockerignore` file:

```dockerfile
.git
!.git/HEAD
!.git/refs
```

Then, set up the creation of a `priv/REVISION file with these two lines in your `Dockerfile`, just before the release gets built:

```dockerfile
COPY rel rel
<<<<<<<
COPY .git .git
RUN cat .git/HEAD | grep "ref: " && (cat .git/HEAD | awk '{print ".git/"$2}' | xargs cat >> priv/REVISION) || cat .git/HEAD >> priv/REVISION
=======
RUN mix release
```

Finally, add the following code to your `config/runtime.exs` to read the created file in the prod environment.

```elixir
revision_file = Path.join([:code.priv_dir(:app_name), "REVISION"])

appsignal_revision =
  revision_file
  |> File.read!()
  |> String.trim()

config :appsignal, :config,
  revision: appsignal_revision
```
This applies to other error-reporting services as well.
"""

drop_6_body = ~S"""
```bash
/bin/bash -c "$(curl -fsSL https://phx.tools/Linux.sh)"
```
for Linux, or
```bash
/bin/bash -c "$(curl -fsSL https://phx.tools/macOS.sh)"
```
for macOS.
"""

user =
  %User{}
  |> User.user_changeset(%{
    avatar: "https://avatars.githubusercontent.com/u/10211884?v=4",
    email: "projects@optimum.ba",
    github_id: 897_654,
    github_username: "optimumBA",
    name: "Optimum"
  })
  |> Repo.insert!()

drop_1 = %{
  title: "Reading .tool-versions file in erlef/setup-beam action",
  body: drop_1_body
}

drop_2 = %{
  title: "Pinning dependency version",
  body: drop_2_body
}

drop_3 = %{
  title: "Overriding max_wait_time in Wallaby tests",
  body: drop_3_body
}

drop_4 = %{
  title: "refute_has in Wallaby test without waiting",
  body: drop_4_body
}

drop_5 = %{
  title: "Setting AppSignal revision",
  body: drop_5_body
}

drop_6 = %{
  title: "Setting up local dev environment",
  body: drop_6_body
}

for drop <- [drop_1, drop_2, drop_3, drop_4, drop_5, drop_6] do
  Drops.create_or_update_drop(%Drop{}, user, drop)
end
