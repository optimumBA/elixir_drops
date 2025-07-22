defmodule ElixirDrops.Repo.Migrations.AddSearchToDrops do
  use Ecto.Migration

  def change do
    alter table(:drops) do
      add :search_vector, :tsvector
    end

    # Create GIN index for fast full-text search
    create index(:drops, [:search_vector], using: :gin)

    # Create function to update search vector
    execute """
            CREATE OR REPLACE FUNCTION update_drops_search_vector()
            RETURNS trigger AS $$
            BEGIN
              NEW.search_vector := 
                setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
                setweight(to_tsvector('english', COALESCE(NEW.body, '')), 'B');
              RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
            """,
            """
            DROP FUNCTION IF EXISTS update_drops_search_vector();
            """

    # Create trigger to automatically update search vector
    execute """
            CREATE TRIGGER update_drops_search_vector_trigger
              BEFORE INSERT OR UPDATE ON drops
              FOR EACH ROW EXECUTE FUNCTION update_drops_search_vector();
            """,
            """
            DROP TRIGGER IF EXISTS update_drops_search_vector_trigger ON drops;
            """

    # Backfill existing drops with search vectors
    execute """
            UPDATE drops SET search_vector = 
              setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
              setweight(to_tsvector('english', COALESCE(body, '')), 'B');
            """,
            ""
  end
end
