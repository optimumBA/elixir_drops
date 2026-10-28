# Source-repository workflows

[check_quint.py](check_quint.py) owns reproducible model validation, scenario tests,
bounded invariant simulations, behavioral witness checks and deliberate-fault checks.
Start at the repository root with [spec/verification.md](../spec/verification.md).
It uses the pinned tool in `quint/`, needs no live integrations, writes a local receipt
and preserves application sources. Maintained receipts belong in `spec/`; scratch
runs and traces belong in ignored `tmp/quint/`.
