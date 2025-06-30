ci:
	MIX_ENV=test mix compile
	MIX_ENV=test mix ci
	MIX_ENV=test mix ecto.rollback --all --quiet
