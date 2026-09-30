# Work Item 4: Exact and Fuzzy Ranking

## Completed

- Added ranked, paginated listing search with a default and maximum page size of 100.
- Exact full-text matches rank first. Fuzzy matching runs only when there is no exact result.
- Recognized makes are preserved during fallback, so an unavailable BMW model returns BMW alternatives first.
- Results include `match_type`, normalized score, `has_next`, and database elapsed time. Ranking is capped at 500 results.

## Verification

- Integration tests passed for BMW M3, `Toyta Camry`, `Ford F150`, special characters, and stable non-overlapping pages.
- `BMW M3` exact search measured about 115 ms.
- Fresh-plan fuzzy searches measured about 589 ms for `Toyta Camry` and 296 ms for `BMW 220e`.
- `EXPLAIN ANALYZE` confirmed the full-text, trigram, and make indexes are used.
