# Vehicle Auction Search MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fast vehicle-auction search page with suggestions, exact search, fuzzy matching, semantic fallback, ranking, pagination, and cache invalidation.

**Architecture:** React calls one Spring Boot API. Spring uses Caffeine and indexed search functions in Supabase PostgreSQL. PostgreSQL full-text search handles direct matches, `pg_trgm` handles fuzzy matches, and pgvector vehicle profiles provide semantic fallback.

**Tech Stack:** Java, Spring Boot, Spring JDBC, Caffeine, React, Vite, Supabase PostgreSQL, `pg_trgm`, pgvector, Supabase Edge Functions.

**Spec:** `docs/superpowers/specs/2026-09-30-vehicle-search-design.md`

## Global Constraints

- Complete a demo-ready MVP in six hours.
- Typical search responses must complete within two seconds.
- Suggestions use a 250 ms debounce and return at most eight entries.
- Exact results rank before fuzzy results; semantic search is the final fallback.
- Default and maximum page size is 100, and results are capped at the top 500.
- Minimum query length is 2; start with trigram similarity `0.30` and semantic similarity `0.55`, then tune only against the fixed demo query set.
- Do not add authentication, Redis, OpenSearch, images, analytics, or live synchronization.

## Review Focus

- Blank or one-character queries return validation errors without querying the database.
- Special characters are safely handled through parameterized SQL.
- A known make with an unknown model returns alternatives from that make first.
- If semantic search is unavailable, fuzzy results still return successfully.
- A failed import does not change `datasetVersion` or clear valid caches.

## Planned Files

```text
database/
  001_schema.sql
  002_search_functions.sql
scripts/
  import-data.sh
backend/
  pom.xml
  src/main/java/com/example/vehiclesearch/
    SearchApplication.java
    search/SearchController.java
    search/SearchService.java
    search/SearchRepository.java
    search/SearchDtos.java
    config/CacheConfig.java
    config/DatasetVersionService.java
  src/test/java/com/example/vehiclesearch/search/
frontend/
  package.json
  src/
    App.jsx
    api/searchApi.js
    hooks/useSuggestions.js
    components/SearchBox.jsx
    components/SearchResults.jsx
    styles.css
supabase/functions/embed/index.ts
```

## Work Items

### 1. Create the runnable project skeleton

**Produces:** A Spring Boot health endpoint and a React page that both start locally.

- [ ] Initialize Git and add a root `.gitignore` and short setup `README.md`.
- [ ] Create the Spring Boot project with Web, Validation, JDBC, PostgreSQL, Cache, and Caffeine dependencies.
- [ ] Write a context-load test, run it failing, then add `SearchApplication` and make it pass.
- [ ] Create the Vite React project and a basic component-render test.
- [ ] Run backend and frontend test commands and commit the skeleton.

### 2. Create the database and import the dataset

**Produces:** A repeatable import that loads the Kaggle CSV into `vehicle_listings`.

- [ ] Write schema checks for required columns, extensions, generated search fields, and indexes.
- [ ] Add `database/001_schema.sql` with `pg_trgm`, `vector`, `vehicle_listings`, `vehicle_profiles`, `suggestion_terms`, and `dataset_metadata`.
- [ ] Add GIN full-text, trigram, make/model, profile, and vector indexes.
- [ ] Write `scripts/import-data.sh` to validate the CSV header, load through a staging table, normalize values, and reject invalid rows.
- [ ] Make the import transactional: activate data and increment `datasetVersion` only after validation succeeds.
- [ ] Run row-count and sample-data checks, rerun the import to prove it is repeatable, and commit.

### 3. Build suggestions

**Produces:** Indexed prefix and typo-tolerant suggestions for makes, models, trims, and common combinations.

- [ ] Write SQL tests for `bm`, `toyota`, `Toyta`, blank input, and an eight-result limit.
- [ ] Populate `suggestion_terms` from normalized listing values with a frequency count.
- [ ] Implement `search_suggestions(query_text, result_limit)` using prefix matching first and trigram similarity second.
- [ ] Verify the query uses the prefix or trigram index with `EXPLAIN ANALYZE`.
- [ ] Commit suggestion generation and search.

### 4. Implement exact and fuzzy ranking

**Produces:** A database function returning ranked, paginated exact or fuzzy results.

- [ ] Write SQL integration tests for an exact model, a misspelling, `Ford F150`, special characters, and page stability.
- [ ] Add `search_vehicle_listings(query_text, page_number, page_size)` to `database/002_search_functions.sql`.
- [ ] Rank exact results with weighted `ts_rank_cd`; give make and model the highest weight.
- [ ] When exact search returns zero rows, rank fuzzy candidates using trigram similarity and partial text score.
- [ ] Preserve a recognized make as a filter or strong boost during fuzzy fallback.
- [ ] Return `match_type`, normalized `score`, `has_next`, and elapsed query data.
- [ ] Verify representative queries with `EXPLAIN ANALYZE` and commit.

### 5. Add semantic vehicle-profile fallback

**Produces:** Natural-language queries and unavailable models return related vehicle listings.

- [ ] Write tests for `family SUV`, `sporty German sedan`, a known make with an unknown model, and embedding-service failure.
- [ ] Generate one profile for each normalized make, model, and body combination and connect listings through `profile_id`.
- [ ] Implement the Supabase `embed` function using `gte-small` and a 384-dimension vector.
- [ ] Generate missing profile embeddings during import without recreating unchanged embeddings.
- [ ] Add a vector search function using cosine similarity and the HNSW index.
- [ ] Invoke semantic search when exact search returns zero and fuzzy search returns fewer than 100 results; fall back to fuzzy-only results on errors.
- [ ] Verify `EXACT`, `FUZZY`, and `SEMANTIC` ordering and commit.

### 6. Build the Spring search API and cache behavior

**Produces:** Validated `/api/search` and `/api/suggestions` endpoints.

- [ ] Write controller and service tests for valid queries, invalid queries, pagination limits, database errors, and semantic degradation.
- [ ] Implement DTOs for suggestions, search items, `matchType`, score, page data, `hasNext`, `datasetVersion`, and elapsed time.
- [ ] Implement `SearchRepository` with parameterized Spring JDBC calls to the database functions.
- [ ] Implement `SearchService` and `SearchController` for both endpoints.
- [ ] Configure Caffeine: suggestions expire after 30 minutes; search pages expire after 5 minutes; both caches have bounded sizes.
- [ ] Implement `DatasetVersionService`: read the single metadata row before cache lookup, detect a version change, and clear both caches.
- [ ] Include the observed `datasetVersion` in every cache key so older entries cannot be reused after import.
- [ ] Test cache hits, TTL configuration, version changes, eviction, and failed-import behavior; then commit.

### 7. Build debounced search suggestions in React

**Produces:** A keyboard-accessible search box with fast suggestions.

- [ ] Write component tests for the 250 ms debounce, eight-item limit, cached prefixes, request cancellation, selection, and empty input.
- [ ] Implement typed API calls in `searchApi.js`.
- [ ] Implement `useSuggestions` with `AbortController` and a session-level `Map` cache.
- [ ] Clear the browser suggestion cache when the API reports a new `datasetVersion`.
- [ ] Implement `SearchBox` with loading, empty, error, keyboard, and submit behavior.
- [ ] Run frontend tests and commit.

### 8. Build results, ranking labels, and pagination

**Produces:** A responsive result list that explains exact, fuzzy, and semantic matches.

- [ ] Write UI tests for loading, empty results, fallback messages, API errors, result cards, and previous/next controls.
- [ ] Implement `SearchResults` showing year, make, model, trim, mileage, condition, price, state, and match type.
- [ ] Show “No exact matches” when fuzzy or semantic fallback is used.
- [ ] Reset to page zero for a new query and prevent navigation beyond the top 500 results.
- [ ] Add simple responsive styling and run accessibility checks for labels, focus, and keyboard use.
- [ ] Run frontend tests and commit.

### 9. Verify performance and prepare the demo

**Produces:** Evidence that the application meets the functional and latency requirements.

- [ ] Create a fixed query set covering exact, fuzzy, semantic, empty, special-character, and paginated requests.
- [ ] Measure cold and warm API timings and record p50 and p95 values.
- [ ] Confirm typical searches finish below two seconds and suggestions do not issue requests before the debounce.
- [ ] Run all backend, frontend, SQL, import-repeatability, and cache-invalidation tests.
- [ ] Run `git diff --check`, review scope against the design, and remove temporary data or secrets.
- [ ] Add concise run, import, test, and demo instructions to `README.md`, then commit the completed MVP.
