#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$project_dir/.env" ]]; then
  set -a
  source "$project_dir/.env"
  set +a
fi

expected_header='year,make,model,trim,body,transmission,vin,state,condition,odometer,color,interior,seller,mmr,sellingprice,saledate'
validate_only=false

if [[ "${1:-}" == "--validate-only" ]]; then
  validate_only=true
  shift
fi

csv_path="${1:-}"
if [[ -z "$csv_path" || ! -f "$csv_path" ]]; then
  echo "usage: $0 [--validate-only] /absolute/path/to/car_prices.csv" >&2
  exit 2
fi

actual_header="$(head -n 1 "$csv_path" | tr -d '\r')"
if [[ "$actual_header" != "$expected_header" ]]; then
  echo "unexpected CSV header" >&2
  echo "expected: $expected_header" >&2
  echo "actual:   $actual_header" >&2
  exit 3
fi

if [[ "$validate_only" == true ]]; then
  echo "CSV header is valid"
  exit 0
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required" >&2
  exit 4
fi

command -v psql >/dev/null 2>&1 || {
  echo "psql is required" >&2
  exit 5
}

echo "Bulk loading $csv_path from this computer into Supabase..."

psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file "$project_dir/scripts/import-data.sql" \
  < "$csv_path"
