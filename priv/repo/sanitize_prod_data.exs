# Sanitization script for production database dumps
# This script anonymizes sensitive user data while preserving all relationships

# Safety checks
if System.get_env("MIX_ENV") == "prod" do
  raise "Cannot run sanitization in production environment!"
end

# Ensure we have a valid database connection
try do
  ElixirDrops.Repo.query!("SELECT 1")
rescue
  DBConnection.ConnectionError ->
    raise "Database connection failed. Please ensure the database is running and accessible."
end

alias ElixirDrops.Repo
import Ecto.Query

IO.puts("Starting database sanitization...")
IO.puts("Environment: #{System.get_env("MIX_ENV") || "development"}")

# Check if we have user data to sanitize
user_count = Repo.aggregate("users", :count, :id)

if user_count == 0 do
  raise "No users found in database. Please restore production dump first."
end

token_count = Repo.aggregate("users_tokens", :count, :id)

IO.puts("Found #{user_count} users and #{token_count} user tokens to process")
IO.puts("Starting sanitization process...")

# Run sanitization in a transaction to ensure atomicity
Repo.transaction(fn ->
  IO.puts("\n1. Sanitizing user data...")

  # Stream through users for memory efficiency
  users_query = from(u in "users", select: [:id])

  users_query
  |> Repo.stream()
  |> Stream.with_index(1)
  |> Stream.each(fn {%{id: id}, index} ->
    # Update user data with anonymized values
    from(u in "users",
      update: [
        set: [
          email: fragment("'user' || ? || '@example.com'", u.id),
          name: fragment("'User ' || ?", u.id),
          github_username: fragment("'user' || SUBSTRING(CAST(? AS text), 1, 8)", u.id),
          avatar: "https://ui-avatars.com/api/?name=User&background=6366f1&color=fff&size=150"
        ]
      ],
      where: u.id == ^id
    )
    |> Repo.update_all([])

    # Progress indicator
    if rem(index, 100) == 0 do
      IO.write("\rProgress: #{index}/#{user_count}")
    end
  end)
  |> Stream.run()

  IO.puts("\n✓ User data sanitized")

  IO.puts("\n2. Deleting user tokens...")

  # Delete all user tokens for security
  {deleted_tokens, _} = Repo.delete_all("users_tokens")
  IO.puts("✓ Deleted #{deleted_tokens} user tokens")

  IO.puts("\n3. Verification...")

  # Verify sanitization worked
  sample_user =
    Repo.one(from u in "users", select: [:email, :name, :github_username, :avatar], limit: 1)

  if sample_user do
    IO.puts("Sample user after sanitization:")
    IO.puts("  Email: #{sample_user.email}")
    IO.puts("  Name: #{sample_user.name}")
    IO.puts("  GitHub Username: #{sample_user.github_username}")
    IO.puts("  Avatar: #{sample_user.avatar}")
  end

  remaining_tokens = Repo.aggregate("users_tokens", :count, :id)
  IO.puts("Remaining user tokens: #{remaining_tokens}")

  if remaining_tokens > 0 do
    raise "Token deletion failed - found #{remaining_tokens} remaining tokens"
  end
end)

IO.puts("\n🎉 Sanitization complete!")
IO.puts("\nNext steps:")
IO.puts("1. Create sanitized dump:")
IO.puts("   pg_dump -Fc --no-owner elixir_drops_dev > elixir_drops_sanitized.dump")
IO.puts("2. Upload dump to Tigris at path: _db/elixir_drops_sanitized.dump")
IO.puts("\nNote: Drop data (code snippets, titles, screenshots) are preserved as-is.")
