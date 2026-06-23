ci:
	@echo "=== CI: compile ==="
	MIX_ENV=test mix compile --warnings-as-errors
	@echo "=== CI: mix ci (deps.unlock, deps.audit, hex.audit, sobelow, format, prettier, credo, dialyzer, test) ==="
	mix ci
	@echo "=== CI: ecto.rollback ==="
	MIX_ENV=test mix ecto.rollback --all --quiet
	@echo "=== CI: ALL PASSED ==="

test: ci
