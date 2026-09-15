# ElixirDrops

This is the Phoenix application behind
[elixirdrops.net](https://elixirdrops.net), a collection of short, practical
Elixir, Phoenix and OTP tips. The repository is published as a
reference for people who want to study or run the application themselves. It
contains the web application and its development workflows, but not production
data, credentials or private campaign records.

> [!NOTE]
> **Open source, closed contribution.** The source code is available under the
> Apache License 2.0. This repository does not accept issues or pull requests and
> is not a public support channel. You are welcome to study the code, fork it and
> adapt it under the license.

## What is included

- Drop publishing, discovery, search, bookmarks and comments.
- GitHub authentication.
- Markdown rendering and generated social-preview images.
- Sponsor placement measurement and reporting.

## Local setup

### Requirements

- Elixir, Erlang and Node versions from [`.tool-versions`](.tool-versions),
  installed with [mise](https://mise.jdx.dev) or equivalent tools.
- PostgreSQL.

### Start the application

1. Install the required runtimes with `mise install`.
2. Start PostgreSQL.
3. Copy [`.env.sample`](.env.sample) to `.env` and provide the values needed for
   the integrations you want to use.
4. Run `mix setup`.
5. Run `mix phx.server`.
6. Open [localhost:4000](http://localhost:4000).

GitHub OAuth and object storage are required for their corresponding production
features. Local development that does not exercise those integrations can leave
their sample values unset.

Tidewave users can follow the current
[MCP proxy setup](https://elixirdrops.net/d/UAo4BtYi).

## Checks

Run the complete project gate before committing:

```sh
make ci
```

For a coverage report, run `mix coveralls` or `mix coveralls.html`. Generate the
Elixir documentation with `mix docs --formatter html --open`.

## Operations documentation

- [Sponsor tracking and reporting](docs/sponsor-tracking.md) explains what is
  measured, how QA traffic is excluded and how delivery reports are produced.

These documents describe the implementation and verification procedures. They
do not authorize access to the hosted service or changes to its production
infrastructure.

## License and product identity

The source code is licensed under the [Apache License 2.0](LICENSE). The license
does not grant permission to operate a modified service as ElixirDrops.

Forks and public deployments must use their own name, logo, visual identity,
domain, content, credentials and data. The ElixirDrops name, logo and associated
brand assets are not licensed under Apache-2.0. You may refer to ElixirDrops only
as reasonably necessary to describe the origin of the software. See
[Product identity](BRANDING.md) for the exact boundary.

## Project map

- `lib/` contains the application and web code.
- `assets/` contains browser code and styles.
- `priv/` contains migrations and static files.
- `test/` contains automated checks and support code.
- `config/` contains compile-time and runtime configuration.
- `docs/` contains maintained operational documentation.
