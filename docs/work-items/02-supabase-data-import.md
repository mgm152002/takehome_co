# Work Item 2: Supabase Dataset Import

## Completed

- Added the Supabase schema for listings, vehicle profiles, suggestions, and dataset metadata.
- Added full-text, trigram, make/model, profile, and vector indexes.
- Added scripts to apply migrations, validate and bulk-import the laptop CSV, and verify the remote schema.
- The import uses a staging table and one transaction. The active data and dataset version change only after a successful import.

## Verification

- CSV records staged: 558,837
- Valid listings imported: 548,438
- Distinct makes: 66
- Distinct models: 973
- Repeat import kept the row count at 548,438 and advanced `datasetVersion` from 1 to 2.
- A timed-out trial rolled back without changing the active rows or version. The import now uses a transaction-local ten-minute timeout for normalization and indexing.
- Schema checks and focused import validation tests passed.

## Run Again

```bash
scripts/apply-migrations.sh
scripts/import-data.sh /absolute/path/to/car_prices.csv
scripts/check-schema.sh
```
