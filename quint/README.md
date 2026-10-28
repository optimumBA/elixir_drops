# Executable ElixirDrops models

Read [spec/README.md](../spec/README.md) for authority, contract rules and known source
differences. These models are intended as agent context and executable design checks;
they do not by themselves certify the running Elixir application.

| Module                         | Responsibility                                                                            |
| ------------------------------ | ----------------------------------------------------------------------------------------- |
| [app.qnt](app.qnt)             | Identity/session lifecycle, publishing, author permissions, comments and notifications    |
| [delivery.qnt](delivery.qnt)   | Screenshot/upload/retry races, enqueue failure, cache TTL/invalidation and sitemap writes |
| [discovery.qnt](discovery.qnt) | Collections, ties/pagination, search tracking/history/suggestions and browser state       |
| [sponsors.qnt](sponsors.qnt)   | Anonymous impressions/clicks, exclusions, redirects, session dedup and reports            |
| [http.qnt](http.qnt)           | HTTP access and representation boundaries                                                 |
| [system.qnt](system.qnt)       | Composed content/delivery admission and interleaving invariants                           |

From the repository root:

```sh
npm ci --prefix quint --ignore-scripts
make spec
```

[Verification workflow](../spec/verification.md) owns commands, trace generation,
failure/resume guidance and completion criteria. [validation.json](../spec/validation.json)
owns the checked result. Keep `node_modules/` and scratch traces untracked; preserve
`package.json` and `package-lock.json` so the same tool is reproducible.
