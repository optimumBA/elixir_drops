# ElixirDrops

ElixirDrops is a Phoenix application for publishing and discovering Elixir tips.

## Start here

- [Local setup](#setup) and [checks](#contributing).
- [Sponsor tracking and reporting](docs/sponsor-tracking.md) — measurement, QA, deployment checks and 30-day reporting.
- [Campaign terms and current work](</Users/almirsarajcic/Library/Mobile Documents/com~apple~CloudDocs/Projects/ElixirDrops - What's next/README.md>).

Folder map: `lib/` owns application and web code; `assets/` browser code and styles;
`priv/` migrations and static files; `test/` automated checks; `config/` runtime
configuration; `docs/` maintained operating procedures.

## Setup

- install Elixir, Erlang and Node using [mise](https://mise.jdx.dev)
  - install mise using either `curl https://mise.run | sh` or `brew install mise`
  - make sure to activate it
  - run `mise install`
- install Tidewave MCP Proxy (https://elixirdrops.net/d/UAo4BtYi)
- start PostgreSQL server
- set environment variables in `.env` (see: [.env.sample](.env.sample))
- run `mix setup`
- start Phoenix server with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Docs

- execute `mix docs --formatter html --open`

It will open documentation in your browser.

## Running tests

- run `mix coveralls` or `mix coveralls.html`

## Contributing

Make sure to execute `make ci` in order to run all the checks before committing the code.
