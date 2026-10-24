#!/usr/bin/env bash
# ============================================================================
# Crystal Messenger — apply the full schema + settings to self-hosted Supabase.
#   * runs supabase/migrations/*.sql in order (idempotent)
#   * verifies pg_net (used by the async push trigger)
#   * sets app.settings.push_* (read by notify_message_push)
#
# Usage:
#   cp deploy/.env.example deploy/.env  # fill secrets
#   bash deploy/apply.sh
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
source deploy/.env
set +a

COMPOSE="docker compose -f deploy/docker-compose.yml"

echo "==> Starting database"
$COMPOSE up -d db
DB_ID="$($COMPOSE ps -q db)"
until docker exec "$DB_ID" pg_isready -U postgres -h localhost >/dev/null 2>&1; do
  echo "    waiting for postgres..."; sleep 2
done

echo "==> Applying migrations"
for f in supabase/migrations/*.sql; do
  echo "    apply $f"
  docker cp "$f" "$DB_ID:/tmp/migration.sql"
  docker exec -u postgres "$DB_ID" psql -v ON_ERROR_STOP=1 -d postgres -f /tmp/migration.sql >/dev/null
done

echo "==> Configuring push + verifying pg_net"
docker exec -u postgres "$DB_ID" psql -v ON_ERROR_STOP=1 -d postgres <<SQL
select extname, extversion from pg_extension where extname = 'pg_net';
alter database postgres set "app.settings.push_function_url" to '${PUSH_FUNCTION_URL}';
alter database postgres set "app.settings.push_service_role_key" to '${SERVICE_ROLE_KEY}';
select count(*) as edge_functions_configured from pg_settings
  where name like 'app.settings.push%';
SQL

echo "==> Done. Next: docker compose -f deploy/docker-compose.yml up -d"