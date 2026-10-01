#!/usr/bin/env bash
# Run the Spring Boot backend, deriving Spring's JDBC datasource settings from
# the libpq-style DATABASE_URL in .env (Supabase gives postgres://USER:PASS@HOST:PORT/DB,
# but Spring/Hikari needs a jdbc:postgresql:// URL plus separate user/password).
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi

: "${DATABASE_URL:?DATABASE_URL is required in .env}"

# Parse postgres://USER:PASS@HOST:PORT/DB
proto_removed="${DATABASE_URL#*://}"
creds="${proto_removed%@*}"
hostpart="${proto_removed#*@}"
DB_USER="${creds%%:*}"
DB_PASS="${creds#*:}"
hostport="${hostpart%%/*}"
DB_NAME="${hostpart#*/}"
DB_NAME="${DB_NAME%%\'*}"
DB_NAME="${DB_NAME%%\"*}"

export SPRING_DATASOURCE_URL="jdbc:postgresql://${hostport}/${DB_NAME}"
export SPRING_DATASOURCE_USERNAME="$DB_USER"
export SPRING_DATASOURCE_PASSWORD="$DB_PASS"
# SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY are already exported from .env for the embed client.

echo "Starting backend → ${SPRING_DATASOURCE_URL} (user=${DB_USER})"
exec mvn -f "$project_dir/backend/pom.xml" -o -Dmaven.repo.local=/private/tmp/copart-m2 spring-boot:run
