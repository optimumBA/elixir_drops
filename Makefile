ci:
	mix ci
	MIX_ENV=test mix ecto.rollback --all --quiet
