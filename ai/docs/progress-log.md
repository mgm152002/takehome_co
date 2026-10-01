# Append-Only Work Item Log
---

## Work Item 1 — Runnable project skeleton

**Status:** Complete
**Commits:** `c191403`, `286d271`

### Completed

- Added the Spring Boot backend and React/Vite frontend.
- Added repository ignores, an environment template, and local run instructions.
- Added baseline backend context and frontend render checks.

### Verification

- Spring context check passed.
- React render check passed.
- Vite production build passed.

### Assumptions and decisions

- Java 21 is the backend target.
- The frontend remains a single-page application.
- Focused checks are preferred over broad low-value test coverage for this MVP.

---

## Work Item 2 — Supabase dataset import

**Status:** Complete
**Commit:** `4e5e38a`

### Completed

- Added ordered Supabase migrations for listings, profiles, suggestions, metadata, generated search fields, and indexes.
- Added a staging-table import with validation, normalization, and transactional activation.
- Advanced `datasetVersion` only after a successful import.

### Verification

- Source rows staged: 558,837.
- Valid listings imported: 548,438.
- Repeat import preserved the expected active row count and advanced the dataset version.
- A timed-out import rolled back without activating partial data.

### Assumptions and decisions

- Applied migrations are treated as append-only deployment assets.
- Dataset refreshes are controlled batch operations.

---

## Work Item 3 — Search suggestions

**Status:** Complete
**Commit:** `19e6fd2`

### Completed

- Generated make, model, trim, and make/model suggestion terms.
- Added prefix-first matching with trigram typo fallback.
- Limited API responses to eight suggestions.
- Integrated suggestion refresh with the import transaction.

### Verification

- Checks passed for `bm`, `toyota`, `Toyta`, blank input, and the result limit.
- Prefix-index use was confirmed with `EXPLAIN ANALYZE`.

### Assumptions and decisions

- Prefix matches rank ahead of fuzzy matches.
- The database owns suggestion ranking; the frontend does not re-filter results.

---

## Work Item 4 — Exact and fuzzy ranking

**Status:** Complete
**Commit:** `b9d8fd9`

### Completed

- Added weighted full-text exact ranking.
- Added trigram fuzzy fallback when exact search returns no rows.
- Added stable pagination, match labels, scores, and elapsed database time.
- Bounded ranking to the top 500 candidates.

### Verification

- Exact, typo, unavailable-model, special-character, and pagination checks passed.
- Representative query measurements were below the two-second target.

### Assumptions and decisions

- A known make should constrain fallback relevance.
- Deep pagination beyond the top 500 is intentionally unavailable.

---

## Work Item 5 — Semantic vehicle-profile fallback

**Status:** Complete
**Commit:** `9187a9d`

### Completed

- Added normalized make/model/body profiles and 384-dimension embeddings.
- Added HNSW nearest-neighbor search.
- Added semantic fallback when exact results are absent and fuzzy results are thin.
- Added fuzzy degradation when embedding generation fails.

### Verification

- Semantic search SQL checks passed.
- Missing embeddings returned no semantic rows without failing lexical search.
- All 892 profiles in the reduced dataset were eventually backfilled.

### Assumptions and decisions

- Profile embeddings are sufficient; individual listings do not need vectors.
- Semantic retrieval is a fallback, not part of every request.

---

## Work Item 6 — Spring API and cache behavior

**Status:** Complete
**Commits:** `ffada5a`, `7cfecb7`

### Completed

- Added a controller/service/repository backend structure.
- Used explicit API DTOs and a separate listing domain model.
- Used `JdbcTemplate` for parameterized PostgreSQL stored-function calls.
- Added 30-minute suggestion and 5-minute search-page Caffeine caches.
- Included `datasetVersion` in cache keys and cleared caches after version changes.

### Verification

- Endpoint validation and response mapping were checked during implementation.
- Repeated-request verification was used to distinguish runtime cache behavior from configuration review; raw logs were not retained.

### Assumptions and decisions

- JPA would add unnecessary mapping and lifecycle overhead for a stored-function-oriented database contract.
- Local Caffeine caches are acceptable while the backend remains single-instance.

---

## Work Item 7 — Debounced frontend suggestions

**Status:** Complete
**Commit:** `b7a0bc0`

### Completed

- Added 250 ms debounce and `AbortController` cancellation.
- Added a session-lifetime per-prefix cache using `useRef`.
- Added loading, empty, error, selection, and keyboard behavior.

### Verification

- Focused suggestion checks covered debounce, request cancellation, and cache behavior.

### Assumptions and decisions

- `useRef` stores operational cache data without triggering unnecessary renders.

---

## Work Item 8 — Results, pagination, and performance UI

**Status:** Complete
**Commit:** `b7a0bc0`

### Completed

- Added MUI X DataGrid results with sorting, filtering, and scrolling.
- Added server-driven pagination and exact/fuzzy/semantic states.
- Added server and client latency history with last, average, p95, and maximum values.

### Verification

- Result rendering, pagination, semantic labels, and performance-panel checks passed during implementation.

### Assumptions and decisions

- The frontend displays measured server query time separately from client round-trip time.

---

## Work Item 9 — Relevance and performance verification

**Status:** Complete
**Commit:** `f14d275`

### Completed

- Restricted exact results to a recognized make, fixing `porsche gt` returning Hyundai results.
- Removed seller text from the search vector and added make aliases, fixing unrelated results for `chevy`.
- Added indexed word similarity for common single-word typos.
- Reworked semantic ranking so HNSW selection happens before threshold filtering and listing fan-out is bounded.

### Verification

- Exact search measured approximately 115 ms in the recorded environment.
- Fuzzy examples measured approximately 296–589 ms.
- Semantic search improved from approximately 810 ms to approximately 86 ms.

### Assumptions and decisions

- Relevance defects must be reproduced and explained before changing ranking logic.
- Very weak typo matches may fall through to semantic search instead of forcing a broad database scan.

---

## Work Item 10 — Cap the working set at 100,000

**Status:** Complete. Embedding follow-up resolved.
**Commit:** Not separately identified in the source ledger.

### Why

The full dataset and indexes created unnecessary storage and maintenance load for the assignment environment. The MVP already bounds ranking to 500 candidates.

### Completed

- Retained the newest 100,000 listings using deterministic sale-date ordering.
- Rebuilt vehicle profiles and suggestion terms.
- Advanced `datasetVersion`, rebuilt indexes, and refreshed planner statistics.
- Added the same limit to future imports.

### Verification

| Object | Before | After |
|---|---:|---:|
| Listings | 548,438 | 100,000 |
| Profiles | 1,253 | 892 |
| Listing table size | About 1 GB | About 419 MB |

### Follow-up

Profile refresh temporarily cleared all embeddings. The edge function was deployed and all 892 profiles were backfilled. Batch size was reduced from 25 to 10 after larger requests exceeded the edge runtime budget.

### Assumptions and decisions

- The newest 100,000 records preserve enough variety for the search demonstration.

---

## Work Item 11 — Bound suggestion-term storage

**Status:** Complete
**Commit:** Not separately identified in the source ledger.

### Why

The reduced listing dataset still produced a long tail of rare trim and combination terms that could not meaningfully reach the top eight suggestions.

### Completed

- Retained every make term.
- Required at least five occurrences for model, trim, and make/model terms.
- Added the threshold to the repeatable refresh function.

### Verification

- Suggestion terms decreased from 2,669 to 1,898.
- Common Toyota and Accord suggestion paths remained available.

### Assumptions and decisions

- Rare terms occurring fewer than five times are autocomplete noise for this MVP.

---

## Work Item 12 — Backend deployment and regional database path

**Status:** Complete
**Commits:** `ad68812`, `43d3c54`, `2382d90`

### Completed

- Added a single-instance Elastic Beanstalk deployment path for the Spring Boot JAR.
- Moved runtime secrets to Elastic Beanstalk environment properties.
- Diagnosed EC2 connectivity failure to the direct IPv6-only Supabase host.
- Switched to the Supabase IPv4 pooler and moved deployment configuration to `us-east-1`.
- Removed hardcoded secret defaults from `application.yml`.

### Verification

- The deployment configuration points to the `us-east-1` environment and pooler.
- Application configuration contains environment-variable references rather than secret defaults.

### Assumptions and decisions

- The backend and database should be colocated to avoid cross-region query latency.
- The runtime requires an IPv4-compatible database endpoint.

---

## Work Item 14 — Netlify production build

**Status:** Repository fix complete; hosted rebuild requires provider verification.
**Commit:** `c531dc7`

### Completed

- Diagnosed that Netlify was serving Vite source files rather than the production bundle.
- Added a build from `frontend`, a `dist` publish directory, and an `/api/*` proxy.

### Verification

- The old deployment HTML referenced `/src/main.jsx`, confirming the source-directory deployment problem.
- Repository configuration now targets the compiled frontend output.

### Assumptions and decisions

- A hosting configuration change is not considered live until the provider finishes and the resulting deployment is inspected.

---

## Work Item 15 — Engineering documentation package

**Status:** Draft; uncommitted
**Commit:** None

### Completed

- Reorganized the root README around architecture, operations, and engineering decisions.
- Added the technical design, assumptions, selected diagrams, work-item record, prompt history, and this append-only log under `ai/docs/`.
- Linked the documentation package from the root README and the AI documentation index.

### Verification

- Markdown whitespace checks pass for the current draft.
- The technical design contains seven focused Mermaid diagrams: architecture, data model, search flow, API flow, cache invalidation, performance validation, and deployment.

### Assumptions and decisions

- Diagrams are used only where relationships or sequences are easier to understand visually.
- Purpose, assumptions, tradeoffs, and out-of-scope sections remain prose or tables.
- Future progress is appended as a new work-item section rather than rewriting committed history.

---
