# Work Items and Delivery Record

This record consolidates the approved implementation plan and the completed delivery summaries. Commit history, source code, and migrations remain the authoritative implementation record.

Chronological assumptions, decisions, evidence, blockers, and resolutions are preserved in the [append-only delivery log](progress-log.md).

## Delivery summary

| # | Work item | Status | Primary outcome |
|---:|---|---|---|
| 1 | Runnable project skeleton | Completed | Spring Boot and React/Vite applications with baseline checks |
| 2 | Supabase schema and dataset import | Completed | Transactional import, validation, search fields, and indexes |
| 3 | Search suggestions | Completed | Prefix-first and typo-tolerant suggestions capped at eight |
| 4 | Exact and fuzzy ranking | Completed | Ranked and paginated PostgreSQL listing search |
| 5 | Semantic profile fallback | Completed | Profile embeddings and vector-based fallback retrieval |
| 6 | Spring API and cache behavior | Completed | Validated endpoints, JDBC repository, DTOs, Caffeine caches |
| 7 | Debounced React suggestions | Completed | Cancellation, session caching, selection, and error states |
| 8 | Results and pagination UI | Completed | Responsive DataGrid, match labels, navigation, performance panel |
| 9 | Verification and deployment readiness | Completed with deployment follow-up | Focused checks, runtime scripts, Elastic Beanstalk and Netlify configuration |
| 10 | Reduce database working set | Completed | Listings reduced to 100,000 and derived structures rebuilt |
| 11 | Bound suggestion-term storage | Completed | Rare long-tail terms filtered; all makes retained |

## Work item details

### 1. Runnable project skeleton

**Objective:** establish independently runnable backend and frontend applications.

**Delivered:**

- Spring Boot application with web, validation, JDBC, PostgreSQL, cache, Caffeine, and health dependencies.
- React and Vite application with a baseline render check.
- Repository ignores, environment template, and local run commands.

**Recorded verification:** Spring context check passed; React render check passed; Vite production build passed.

### 2. Supabase schema and dataset import

**Objective:** create a repeatable, failure-safe ingestion path for the auction CSV.

**Delivered:**

- Ordered Supabase migrations for listings, profiles, suggestions, metadata, extensions, generated fields, and indexes.
- Staging-table import with header validation, normalization, and transactional activation.
- Dataset-version advancement only after a successful import.
- Schema and import verification scripts.

**Recorded verification:** the initial full import staged 558,837 rows and accepted 548,438 valid listings. A repeat import preserved the row count and advanced the dataset version. A timed-out trial rolled back without activating partial data.

### 3. Search suggestions

**Objective:** provide fast make/model/trim suggestions with typo recovery.

**Delivered:**

- Suggestion generation from normalized listing values.
- Prefix matches ranked before trigram matches.
- Eight-result response cap.
- Derived-term refresh integrated with dataset imports.

**Recorded verification:** representative checks covered `bm`, `toyota`, `Toyta`, blank input, and the result limit. Prefix-index use was confirmed; PostgreSQL preferred a small sequential scan for fuzzy matching when the table was small.

### 4. Exact and fuzzy ranking

**Objective:** return stable, paginated lexical search results.

**Delivered:**

- Weighted full-text ranking for direct matches.
- Trigram fallback when exact search is empty.
- Recognized-make preservation during fuzzy fallback.
- Match type, normalized score, pagination state, and elapsed database time.
- Top-500 ranking boundary.

**Recorded verification:** exact, typo, unavailable-model, special-character, and stable-page scenarios passed. Point-in-time database measurements were approximately 115 ms for an exact BMW M3 query, 589 ms for `Toyta Camry`, and 296 ms for `BMW 220e`.

### 5. Semantic vehicle-profile fallback

**Objective:** return useful alternatives for natural-language or unavailable-model queries.

**Delivered:**

- Normalized make/model/body profiles linked to listings.
- Supabase embedding function using 384-dimension `gte-small` vectors.
- HNSW cosine search over vehicle profiles.
- Conditional semantic fallback after weak lexical retrieval.
- Fuzzy-only degradation when embeddings are unavailable.

**Recorded verification:** all 892 profiles in the reduced working set were backfilled with embeddings, and the vector ordering path was checked. Edge-function batches were reduced to ten inputs after larger batches exceeded the runtime budget.

### 6. Spring API and cache behavior

**Objective:** expose stable HTTP contracts and isolate transport, business, and data-access concerns.

**Delivered:**

- `/api/search` and `/api/suggestions` controllers with validation.
- Service-level exact/fuzzy/semantic policy.
- Parameterized Spring JDBC repository calls.
- Consistent response DTOs and API error handling.
- Caffeine suggestion and search-page caches keyed by dataset version.

### 7. Debounced React suggestions

**Objective:** make autocomplete responsive without issuing unnecessary requests.

**Delivered:**

- 250 ms debounce.
- `AbortController` cancellation for obsolete requests.
- Session-level prefix cache.
- Loading, empty, error, selection, and keyboard behavior.

### 8. Results, ranking labels, and pagination

**Objective:** present search results and fallback behavior clearly.

**Delivered:**

- Responsive result grid with vehicle and sale fields.
- Exact, fuzzy, and semantic match labels.
- Previous/next pagination and new-query page reset.
- Loading, empty, and API-error states.
- Search timing/performance panel.

### 9. Verification and deployment readiness

**Objective:** prepare the application for review and hosted execution.

**Delivered:**

- Focused frontend, backend, SQL, schema, and import checks during implementation.
- Local run scripts and Elastic Beanstalk deployment helper.
- Netlify production build and `/api/*` proxy configuration.
- Environment-based runtime configuration and a repository secret review.

**Follow-up:** hosting-provider deployment status must be confirmed from the latest build after configuration changes; repository configuration alone does not prove the live deployment is healthy.

### 10. Reduce database working set to 100,000

**Objective:** reduce storage, reindex cost, and shared-database load without changing the demonstrated search flow.

**Delivered:**

- Deterministically retained the newest 100,000 listings.
- Rebuilt vehicle profiles and suggestion terms.
- Advanced the dataset version and rebuilt planner statistics/indexes.
- Applied the same cap to future imports.

**Recorded point-in-time state:** 100,000 listings, 892 profiles, and approximately 419 MB for the listing table after maintenance.

### 11. Bound suggestion-term storage

**Objective:** remove autocomplete terms that cannot meaningfully reach the top results.

**Delivered:**

- Retained all make terms.
- Required a frequency of at least five for model, trim, and make/model combinations.
- Applied the rule both to live data and the repeatable refresh function.

**Recorded point-in-time state:** suggestion terms decreased from 2,669 to 1,898 without removing common make/model suggestions.

## Material delivery decisions

- Supabase migrations were treated as ordered, append-only deployment assets.
- Verification emphasized search behavior, cache invalidation, pagination, and executable database checks instead of broad low-value unit coverage.
- A smaller deterministic working set was preferred over operating the complete historical archive in a shared database.
- Secret values remained in ignored local configuration or deployment environment settings.
- Feature work was promoted to `main`, which was configured as the repository default branch.
