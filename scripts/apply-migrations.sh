#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 2
fi

command -v psql >/dev/null 2>&1 || {
  echo "psql is required" >&2
  exit 3
}

for migration in "$project_dir"/supabase/migrations/*.sql; do
  echo "Applying $(basename "$migration")..."
  psql "$DATABASE_URL" --set ON_ERROR_STOP=1 --file "$migration"
done
