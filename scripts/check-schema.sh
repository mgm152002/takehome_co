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

psql "$DATABASE_URL" --set ON_ERROR_STOP=1 <<'SQL'
do $$
declare
    missing text[] := array[]::text[];
begin
    if not exists (select 1 from pg_extension where extname = 'pg_trgm') then
        missing := array_append(missing, 'extension pg_trgm');
    end if;
    if not exists (select 1 from pg_extension where extname = 'vector') then
        missing := array_append(missing, 'extension vector');
    end if;
    if to_regclass('public.vehicle_listings') is null then
        missing := array_append(missing, 'table vehicle_listings');
    end if;
    if to_regclass('public.vehicle_profiles') is null then
        missing := array_append(missing, 'table vehicle_profiles');
    end if;
    if to_regclass('public.suggestion_terms') is null then
        missing := array_append(missing, 'table suggestion_terms');
    end if;
    if to_regclass('public.dataset_metadata') is null then
        missing := array_append(missing, 'table dataset_metadata');
    end if;
    if to_regclass('public.vehicle_listings_search_idx') is null then
        missing := array_append(missing, 'index vehicle_listings_search_idx');
    end if;
    if to_regclass('public.vehicle_listings_title_trgm_idx') is null then
        missing := array_append(missing, 'index vehicle_listings_title_trgm_idx');
    end if;
    if to_regclass('public.vehicle_profiles_embedding_idx') is null then
        missing := array_append(missing, 'index vehicle_profiles_embedding_idx');
    end if;
    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'vehicle_listings'
          and column_name = 'search_vector'
          and is_generated = 'ALWAYS'
    ) then
        missing := array_append(missing, 'generated column search_vector');
    end if;
    if cardinality(missing) > 0 then
        raise exception 'schema check failed: %', array_to_string(missing, ', ');
    end if;
end
$$;

select 'schema checks passed' as result;
SQL
