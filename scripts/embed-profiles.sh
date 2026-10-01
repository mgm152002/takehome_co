#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi

for required_name in DATABASE_URL SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
  if [[ -z "${!required_name:-}" ]]; then
    echo "$required_name is required" >&2
    exit 2
  fi
done

command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 3; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 3; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 3; }

batch_size=25
processed=0

while true; do
  batch="$(
    psql "$DATABASE_URL" --set ON_ERROR_STOP=1 --tuples-only --no-align <<SQL
select coalesce(
    json_agg(json_build_object('id', id, 'input', profile_text)),
    '[]'::json
)::text
from (
    select id, profile_text
    from public.vehicle_profiles
    where embedding is null
    order by id
    limit $batch_size
) missing;
SQL
  )"

  batch_count="$(jq 'length' <<<"$batch")"
  if [[ "$batch_count" -eq 0 ]]; then
    break
  fi

  response="$(
    curl --fail-with-body --silent --show-error \
      --request POST "$SUPABASE_URL/functions/v1/embed" \
      --header "Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY" \
      --header "apikey: $SUPABASE_PUBLISHABLE_KEY" \
      --header 'Content-Type: application/json' \
      --data "$(jq -cn --argjson inputs "$batch" '{inputs: $inputs}')"
  )"

  embeddings="$(jq -c '.embeddings // error("missing embeddings")' <<<"$response")"
  response_count="$(jq 'length' <<<"$embeddings")"
  if [[ "$response_count" -ne "$batch_count" ]]; then
    echo "embedding response count mismatch" >&2
    exit 4
  fi

  psql "$DATABASE_URL" \
    --set ON_ERROR_STOP=1 \
    --set embeddings="$embeddings" <<'SQL'
update public.vehicle_profiles profiles
set embedding = generated.embedding::text::extensions.vector,
    updated_at = now()
from jsonb_to_recordset(:'embeddings'::jsonb)
    as generated(id bigint, embedding jsonb)
where profiles.id = generated.id
  and profiles.embedding is null;
SQL

  processed=$((processed + batch_count))
  echo "Embedded $processed profiles"
done

echo "Profile embedding backfill complete ($processed updated)"
