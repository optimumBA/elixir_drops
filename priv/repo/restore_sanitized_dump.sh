#!/bin/bash

# Optimized restoration script for sanitized database dumps
# Used by preview apps to quickly restore sanitized production data

set -e

DUMP_FILE="${1:-elixir_drops_sanitized.dump}"
DATABASE="${2:-$DATABASE_URL}"

if [ -z "$DATABASE" ]; then
    echo "Error: DATABASE_URL not set and no database specified"
    exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "Starting optimized restoration of sanitized dump..."
echo "Dump file: $DUMP_FILE"
echo "Database: $DATABASE"

# Extract database name from URL for direct connection
DB_NAME=$(echo "$DATABASE" | sed 's/.*\/\([^?]*\).*/\1/')
echo "Database name: $DB_NAME"

# Phase 1: Restore schema only (fast)
echo "Phase 1: Restoring database schema..."
pg_restore \
    --dbname="$DATABASE" \
    --no-owner \
    --no-privileges \
    --schema-only \
    --clean \
    --if-exists \
    --verbose \
    "$DUMP_FILE"

echo "✓ Schema restoration complete"

# Phase 2: Restore data (bulk load)
echo "Phase 2: Restoring data..."
pg_restore \
    --dbname="$DATABASE" \
    --no-owner \
    --no-privileges \
    --data-only \
    --disable-triggers \
    --verbose \
    "$DUMP_FILE"

echo "✓ Data restoration complete"

# Phase 3: Create indexes and constraints (parallel)
echo "Phase 3: Creating indexes and constraints..."

# Re-enable triggers and create indexes
psql "$DATABASE" -c "
-- Re-enable triggers
SET session_replication_role = DEFAULT;

-- Create indexes in parallel where possible
SET maintenance_work_mem = '256MB';
SET max_parallel_maintenance_workers = 4;

-- Analyze tables for query optimization
ANALYZE;
"

echo "✓ Indexes and constraints created"

# Phase 4: Final optimization
echo "Phase 4: Final optimization..."
psql "$DATABASE" -c "ANALYZE;"

# Run VACUUM separately (can't run in transaction block)
echo "Running VACUUM..."
psql "$DATABASE" -c "VACUUM;"

echo "✓ Database optimization complete"

# Verify restoration
echo "Verifying restoration..."
USER_COUNT=$(psql "$DATABASE" -t -c "SELECT COUNT(*) FROM users;" | xargs)
DROP_COUNT=$(psql "$DATABASE" -t -c "SELECT COUNT(*) FROM drops;" | xargs)
TOKEN_COUNT=$(psql "$DATABASE" -t -c "SELECT COUNT(*) FROM users_tokens;" | xargs)

echo "Restoration summary:"
echo "  Users: $USER_COUNT"
echo "  Drops: $DROP_COUNT"
echo "  User tokens: $TOKEN_COUNT (should be 0 for sanitized data)"

if [ "$TOKEN_COUNT" -gt 0 ]; then
    echo "Warning: Found $TOKEN_COUNT user tokens in sanitized data"
fi

echo "🎉 Sanitized database restoration complete!"
