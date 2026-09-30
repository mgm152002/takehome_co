#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d /private/tmp/vehicle-search-import-test.XXXXXX)"
trap 'rm -rf "$fixture_dir"' EXIT

valid_csv="$fixture_dir/valid.csv"
invalid_csv="$fixture_dir/invalid.csv"

printf '%s\n' \
  'year,make,model,trim,body,transmission,vin,state,condition,odometer,color,interior,seller,mmr,sellingprice,saledate' \
  '2015,BMW,M3,Base,Sedan,automatic,TESTVIN,ca,4.5,50000,black,black,Test Seller,30000,32000,2015-01-01' \
  > "$valid_csv"

printf '%s\n' 'year,make,wrong_column' '2015,BMW,M3' > "$invalid_csv"

"$project_dir/scripts/import-data.sh" --validate-only "$valid_csv"

if "$project_dir/scripts/import-data.sh" --validate-only "$invalid_csv"; then
  echo "expected invalid header to be rejected" >&2
  exit 1
fi

if ! grep -Fq "set local statement_timeout = '10min';" "$project_dir/scripts/import-data.sql"; then
  echo "expected import transaction to allow a ten-minute normalization step" >&2
  exit 1
fi

echo "import validation checks passed"
