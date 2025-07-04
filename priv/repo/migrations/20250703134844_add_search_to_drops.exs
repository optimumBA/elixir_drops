defmodule ElixirDrops.Repo.Migrations.AddSearchToDrops do
  use Ecto.Migration

  def up do
    # Add search vector column
    alter table(:drops) do
      add :search_vector, :tsvector
    end

    # Create GIN index for full-text search performance
    create index(:drops, [:search_vector], using: :gin)

    # Create index on inserted_at for better homepage performance
    create index(:drops, [:inserted_at])

    # Create trigger to automatically update search vector
    execute """
    CREATE OR REPLACE FUNCTION drops_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.body, '')), 'B');
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER drops_search_vector_trigger
    BEFORE INSERT OR UPDATE ON drops
    FOR EACH ROW EXECUTE FUNCTION drops_search_vector_update();
    """

    # Update existing records
    execute """
    UPDATE drops SET search_vector =
      setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(body, '')), 'B');
    """
  end

  def down do
    drop index(:drops, [:search_vector])
    drop index(:drops, [:inserted_at])

    execute "DROP TRIGGER IF EXISTS drops_search_vector_trigger ON drops;"
    execute "DROP FUNCTION IF EXISTS drops_search_vector_update();"

    alter table(:drops) do
      remove :search_vector
    end
  end
end
