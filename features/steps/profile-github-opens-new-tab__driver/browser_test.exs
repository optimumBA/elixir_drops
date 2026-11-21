defmodule ProfileGithubOpensNewTab.BrowserTest do
  use ElixirDropsWeb.ConnCase, async: false

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops.Drop

  @moduletag :feature

  test "activating View on GitHub opens one new context and leaves the profile tab unchanged" do
    owner = user_fixture(%{name: "Bea Browser", github_username: "bea_browser_owner"})
    drop_fixture(%Drop{}, owner, %{title: "Browser profile piece"})

    # The endpoint's configured host is localhost; another origin fails the socket origin check.
    port = System.get_env("PORT_TEST") || "4100"
    base = "http://localhost:#{port}"
    path = "/u/#{owner.id}"
    github = "https://github.com/bea_browser_owner"

    script = Path.expand("features/steps/profile-github-opens-new-tab__driver/new_tab.cjs")
    {output, status} = System.cmd("node", [script, base, path, github], stderr_to_stdout: true)
    assert status == 0, "new_tab.cjs exited #{status}: #{output}"

    json = output |> String.split("\n", trim: true) |> List.last()
    result = Jason.decode!(json)

    assert result["pagesAfter"] - result["pagesBefore"] == 1,
           "expected exactly one new browsing context: #{json}"

    assert result["popupUrl"] == github, "new context not at the GitHub URL: #{json}"
    assert result["originalUrl"] == base <> path, "original tab URL changed: #{json}"

    assert result["textBefore"] != nil and result["textAfter"] == result["textBefore"],
           "original page content changed: #{json}"

    # Every non-local request is answered by the fixture (github.com) or aborted by the
    # script, so the GitHub fixture page, not the outside network, served the new context.
    assert result["githubRequests"] != [], "GitHub fixture was never requested: #{json}"
  end
end
