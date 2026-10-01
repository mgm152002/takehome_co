# Prompts and Responses

**Model used:** GPT-5.6 Sol

## Phase 1 — Problem framing and delivery design

### 1. Assignment requirements and six-hour architecture plan

**Prompt**

> I have an assignment to implement search over a large dataset. It should include a simple UI with a search input and button, optimistic search suggestions, and a paginated list ranked by relevance.
>
> **Functional requirements**
>
> - Users can search the provided dataset by entering a query.
> - Relevant suggestions appear while the user is typing.
> - After submitting, users see relevant items ranked by relevance.
> - If no direct match exists, return probable results based on semantic meaning and rank them appropriately.
>
> **Non-functional requirements**
>
> - Search results should appear within two seconds of submission.
> - Suggestions should use debounce and caching to avoid overloading the backend.
> - The application should handle a large dataset.
> - Query caching and invalidation should improve repeated-query performance.
> - Database queries should be optimized for fast results.
>
> **Technology constraints**
>
> - Java and Spring Boot backend
> - React frontend
> - Supabase database
> - An appropriate semantic-search solution or external library may be used
>
> I have six uninterrupted hours to implement this. Provide a high-level plan and architecture, remove unnecessary scope and explain each cut, keep the design simple, and make the UI functional and fast. Produce a design document for the solution.

**Response and outcome**

A six-hour MVP plan was defined around React, Spring Boot, and Supabase PostgreSQL. PostgreSQL full-text search handles direct matches, `pg_trgm` handles misspellings, and pgvector profile embeddings handle semantic fallback. Caffeine provides bounded backend caching, while a dataset-version value invalidates stale cache entries after imports. Authentication, saved searches, images, analytics, advanced filters, Redis, OpenSearch, and live synchronization were excluded to protect the delivery window. The resulting design is captured in [design.md](design.md).

### 2. Find a Copart-style open-source dataset

**Prompt**

> Find a relevant open-source dataset for this assignment. It should resemble Copart-style vehicle-auction listings.

**Response and outcome**

The project selected the Kaggle Vehicle Sales Data dataset by Syed Anwar Afridi. It contains approximately 559,000 historical vehicle-auction records with fields such as year, make, model, trim, body, condition, odometer, market value, selling price, seller, state, and sale date. The structure is close enough to a Copart-style listing catalog to demonstrate ranking, typo recovery, pagination, and semantic alternatives.

Dataset: [Vehicle Sales Data on Kaggle](https://www.kaggle.com/datasets/syedanwarafridi/vehicle-sales-data)

### 3. Create the concise design document

**Prompt**

> Go ahead and create the design file. Keep it concise and include only relevant information, the architecture, important tradeoffs, and the reasons for cutting scope. Do not make it too long.

**Response and outcome**

A concise design document was created with the system architecture, data model, search stages, API contract, caching and invalidation policy, performance strategy, implementation sequence, acceptance criteria, tradeoffs, and explicit scope cuts. The current consolidated version is available in [design.md](design.md).

### 4. Divide the design into work items and maintain an append-only progress log

**Prompt**

> Divide the approved design into clear work items that can be implemented one at a time. After completing each work item, append its progress, decisions, verification evidence, blockers, and relevant commit range to a progress log. Keep the log append-only so the delivery history is preserved rather than rewritten.

**Response and outcome**

The design was decomposed into nine initial delivery work items covering the project skeleton, data import, suggestions, exact and fuzzy ranking, semantic fallback, backend APIs and caching, frontend suggestions, results and pagination, and final verification. Two later optimization requests became Work Items 10 and 11. An append-only execution ledger recorded implementation rulings, commit ranges, verification commands, results, blockers, and follow-up resolutions. The completed record is consolidated in [work-items.md](work-items.md).

### 5. Keep verification focused

**Prompt**

> Keep the automated test suite small and focused. Prioritize validation, ranking-mode selection, cache invalidation, debounce behavior, pagination, and executable SQL checks rather than adding low-value tests for every wiring layer.

**Response and outcome**

Verification concentrated on Spring context and API behavior, React interaction paths, import safety, SQL ranking, index use, typo recovery, pagination stability, and representative semantic queries. This kept delivery aligned with the MVP timeline.

## Phase 2 — Platform and search foundation

### 6. Use Supabase as the data platform

**Prompt**

> Use Supabase PostgreSQL for the schema, search functions, vector storage, and deployment-ready database workflow. Keep migrations ordered and make the CSV import repeatable and safe.

**Response and outcome**

The schema and search logic were implemented as ordered Supabase migrations. The importer validates the source, stages rows, normalizes data, refreshes derived tables, and activates changes transactionally. Failed imports do not advance the dataset version.

### 7. Enforce a strict three-layer Spring backend

**Prompt**

> Build the search API in a strict three-layer Spring pattern: `@RestController` for HTTP and validation only, `@Service` for business logic with no servlet types, and `@Repository` for database access. Use explicit wire DTOs and a separate domain model. The dataset is exposed through PostgreSQL stored functions for full-text, trigram, and pgvector search, so use `JdbcTemplate` rather than JPA and explain the decision.

**Response and outcome**

The backend separates HTTP mapping and validation in `SearchController`, fallback and cache policy in `SearchService`, and stored-function calls in `SearchRepository`. API records are distinct from the `VehicleListing` domain model. `JdbcTemplate` was selected because the database contract consists of parameterized PostgreSQL functions and pgvector values; JPA entity lifecycle and object-relational mapping would add complexity without improving this function-oriented access pattern.

### 8. Add version-aware Caffeine caches

**Prompt**

> Add Caffeine in-memory caching with a `suggestions` cache using a 30-minute TTL and a `searchPages` cache using a 5-minute TTL. Include `datasetVersion` in the cache keys so a data re-import invalidates stale entries.

**Response and outcome**

Two bounded Caffeine caches were configured with the requested TTLs. Suggestion keys include the normalized query and dataset version; search keys include normalized query, page, size, and dataset version. `DatasetVersionService` detects version changes and clears both caches, while versioned keys prevent old entries from being reused.

### 9. Implement exact and fuzzy search first

**Prompt**

> Rank direct make, model, and year matches first. When no exact result exists, recover misspellings with fuzzy search and keep a recognized manufacturer relevant. Return match type, score, pagination state, and timing information.

**Response and outcome**

Weighted full-text and trigram search functions were added with stable ordering and a top-500 ranking boundary. Queries such as `Toyta Camry` recover Toyota results, while unavailable BMW models prefer BMW alternatives instead of unrelated makes.

### 10. Add semantic fallback without weakening direct search

**Prompt**

> Add semantic retrieval for natural-language queries and unavailable models, but invoke it only when lexical search is insufficient. Avoid embedding every auction record, and ensure semantic failures degrade gracefully.

**Response and outcome**

Distinct vehicle profiles were embedded instead of individual listings. Semantic search runs only when exact results are absent and fuzzy coverage is thin. Embedding or vector-search failures return fuzzy results rather than failing the request.

## Phase 3 — Relevance debugging and measured validation

### 11. Diagnose incorrect EXACT results for `porsche gt`

**Prompt**

> A search for `porsche gt` returns a Hyundai Tiburon GT as an EXACT match. Trace the query against the live search function and explain the root cause before changing anything.

**Response and outcome**

The exact tier recognized `porsche` but used the make only as a score boost. A different manufacturer could still qualify because `gt` matched its full-text vector. The exact-stage predicate was corrected so that, when a known make is recognized, exact candidates must belong to that make. If no exact row remains, the request proceeds to fuzzy or semantic fallback.

### 12. Diagnose unrelated results for `chevy`

**Prompt**

> A search for `chevy` returns Toyotas. Diagnose the behavior against the live database, identify the real source of the match, and fix it properly.

**Response and outcome**

The search vector originally included seller text, and a seller containing “chevy auto body” caused unrelated Toyota listings to qualify. The fix added a make-alias normalization map—including `chevy` to `chevrolet` and `vw` to `volkswagen`—and limited the generated search vector to make, model, trim, and body. This removed seller-name contamination while supporting common manufacturer nicknames.

### 13. Recover single-word fuzzy typos without losing index support

**Prompt**

> Fuzzy search misses single-word typos such as `camri` and `accrd`. Reproduce the behavior across several typos, identify the trigram-threshold tradeoff, and choose a fix that remains index-backed and within the two-second budget. Do not thrash between speculative fixes.

**Response and outcome**

Whole-title similarity diluted a short misspelled word against a long normalized vehicle title. The fuzzy tier now combines `word_similarity`, which compares against the best matching word, with full-title similarity. The index-backed trigram word operator recovers common cases such as `camri`, `corola`, and `sivic`. Extremely weak matches such as `accrd`, below the database-wide word-similarity threshold, intentionally continue to semantic fallback rather than forcing a broad scan.

### 14. Measure the two-second acceptance criterion

**Prompt**

> Does the implementation meet the under-two-second acceptance criterion? Measure exact, fuzzy, and semantic retrieval against the live 100,000-row dataset. Do not claim compliance without timing it.

**Response and outcome**

The three retrieval paths were timed against the reduced live dataset. Representative point-in-time measurements included approximately 115 ms for exact search, 296–589 ms for fuzzy examples, and approximately 86 ms for the optimized semantic query. These measurements met the two-second target in that environment and were documented as evidence rather than a permanent service-level guarantee.

### 15. Prove the semantic query uses HNSW

**Prompt**

> Run `EXPLAIN ANALYZE` on the semantic query, confirm whether PostgreSQL actually uses the HNSW index, and provide the complete runnable command.

**Response and outcome**

The original threshold predicate forced distance re-evaluation, while joining every matched profile to all of its listings created a large sort fan-out. The query was changed to perform pure nearest-neighbor HNSW ordering first, apply the similarity threshold afterward, and cap listings per profile before the global sort. The recorded runtime improved from approximately 810 ms to approximately 86 ms.

A repeatable planner check can use an existing profile vector without placing a vector literal in documentation:

```bash
set -a; source .env; set +a
psql "$DATABASE_URL" <<'SQL'
select embedding::text as query_vector
from public.vehicle_profiles
where embedding is not null
limit 1
\gset

explain (analyze, buffers)
select id
from public.vehicle_profiles
where embedding is not null
order by embedding <=> :'query_vector'::extensions.vector
limit 40;
SQL
```

### 16. Verify that Caffeine is hitting at runtime

**Prompt**

> Verify that the Caffeine cache actually hits. Prove it with runtime evidence rather than reviewing configuration and assuming it works.

**Response and outcome**

The verification compared repeated identical suggestion and search requests using repository/database invocation evidence and request timing: the first request populated the relevant cache, while the repeated request was expected to return without another database lookup. A dataset-version change was then used to exercise invalidation. The raw runtime log was not retained in the repository, so this record preserves the evidence standard and verification method rather than claiming a permanent cache-hit metric.

## Phase 4 — Frontend implementation and code understanding

### 17. Build a usable search interface

**Prompt**

> Build a responsive React search page with debounced suggestions, cancellation of stale requests, ranked results, match labels, pagination, loading and error states, and visible search-performance information.

**Response and outcome**

The frontend includes suggestion caching, request cancellation, a Material UI result grid, exact/fuzzy/semantic labels, pagination controls, empty/error states, and a performance panel.

### 18. Build the complete frontend search experience

**Prompt**

> Add 250 ms debounced autocomplete against `/api/suggestions`, with `AbortController` cancellation and a per-prefix cache. Use MUI X DataGrid for results with built-in column sorting and filtering, sticky-header scrolling, and server-side pagination. Display server query time and a session latency chart comparing server `elapsedMs` with client round-trip time, including p95.

**Response and outcome**

The React frontend implements debounced and cancellable suggestions, a session prefix cache, a DataGrid result experience, server-driven page requests, and explicit exact/fuzzy/semantic states. A session performance panel records the latest 15 searches, charts server and client latency, and displays last, average, p95, maximum, query count, and current match mode.

### 19. Explain the `useRef` cache design

**Prompt**

> Explain how `useRef` is used for the client-side cache and why it is preferable to `useState` for this purpose.

**Response and outcome**

`useRef` holds mutable `Map` instances for suggestion and search-result caches across renders without making cache writes trigger UI renders. Components read and update `.current` inside request logic, while visible values such as results, loading state, errors, and performance history remain in `useState`. Using state for the cache itself would create unnecessary renders and stale-closure concerns for data that is operational rather than directly rendered.

## Phase 5 — Data-volume optimization

### 20. Reduce the live database load

**Prompt**

> Limit the active dataset to 100,000 listings to reduce shared-database storage and maintenance load. Keep the reduction deterministic, rebuild dependent profiles and suggestions, refresh indexes and statistics, and make future imports apply the same rule.

**Response and outcome**

The newest 100,000 listings were retained using deterministic sale-date ordering. Vehicle profiles and suggestions were rebuilt, the dataset version was advanced, indexes and statistics were refreshed, and future imports were updated to enforce the same cap.

### 21. Reduce the suggestion table's long tail

**Prompt**

> The suggestion table still contains more than two thousand rows after reducing the listing dataset. Remove low-value rare terms without affecting common make and model autocomplete results, and make the rule repeatable.

**Response and outcome**

All makes were retained. Models, trims, and combinations now require at least five occurrences. The same threshold was added to the refresh function, reducing the recorded table size from 2,669 to 1,898 terms.

## Phase 6 — Deployment and production diagnosis

### 22. Prepare the application for hosting

**Prompt**

> Package the Spring Boot backend for AWS Elastic Beanstalk and configure the React frontend for Netlify. Runtime credentials must come from environment variables and must not be committed.

**Response and outcome**

The repository includes a backend process definition, an Elastic Beanstalk deployment helper, environment-based Spring configuration, and a Netlify build definition. The frontend build runs from `frontend`, publishes `dist`, and proxies `/api/*` to the backend.

### 23. Deploy the backend without committing secrets

**Prompt**

> Deploy the Spring Boot JAR to a single-instance AWS Elastic Beanstalk environment using Corretto 21. Explain exactly where runtime secrets belong; they must not be stored in `application.yml`.

**Response and outcome**

The backend was packaged as a runnable JAR with a platform process definition. Database and Supabase settings are injected as Elastic Beanstalk environment properties. `application.yml` contains environment-variable references only, while local values remain in the ignored `.env` file.

### 24. Diagnose frontend failures against Elastic Beanstalk

**Prompt**

> Frontend requests are failing against the Elastic Beanstalk URL. Determine whether the failure is in the frontend proxy or the backend before changing configuration.

**Response and outcome**

The proxy reached the backend, but the backend could not connect to the direct Supabase database host because that endpoint was IPv6-only from the EC2 environment. The deployment was switched to the Supabase IPv4 pooler, using the pooler region and connection details reported by the Supabase tooling. This resolved the network path at the database boundary rather than masking it in the frontend.

### 25. Recreate the backend near the database

**Prompt**

> Tear down the Elastic Beanstalk environment in `ap-south-1` and recreate it in `us-east-1` so the backend is colocated with the database.

**Response and outcome**

The deployment configuration and frontend proxy were updated to the `us-east-1` Elastic Beanstalk environment and the matching Supabase pooler region. Colocating the application and database reduced avoidable cross-region latency on each search request.

### 26. Diagnose and correct the blank Netlify page

**Prompt**

> Determine why the Netlify deployment renders a blank page and configure it to serve the compiled React application rather than source files.

**Response and outcome**

The deployed HTML referenced `/src/main.jsx`, proving that Netlify was serving the Vite source directory instead of the production bundle. A root `netlify.toml` now builds from `frontend`, publishes `dist`, and defines the production API proxy. Live deployment health remains a hosting-platform verification step after the rebuild completes.
