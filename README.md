# Vehicle Auction Search

Search a large vehicle-auction dataset with exact, fuzzy, and semantic fallback ranking.

## Project layout

- `backend` — Spring Boot API
- `frontend` — React and Vite UI
- `database` — Supabase PostgreSQL schema and search functions
- `scripts` — repeatable dataset import
- `docs` — design, work items, and completion summaries

Detailed setup commands will be added as each work item is implemented.

## Run locally

```bash
cd backend
mvn spring-boot:run
```

```bash
cd frontend
npm install
npm run dev
```

Run the current tests with `mvn test` in `backend` and `npm test` in `frontend`.
