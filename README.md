# Vehicle Auction Search

Search a large vehicle-auction dataset with exact, fuzzy, and semantic fallback ranking.

## Project layout

- `backend` — Spring Boot API
- `frontend` — React and Vite UI
- `supabase/migrations` — Supabase PostgreSQL schema and search functions
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

## Supabase data setup

1. Copy `.env.example` to `.env` and set `DATABASE_URL` to a working PostgreSQL connection URI from Supabase's **Connect** dialog. Keep this file local; it is ignored by Git.
2. Apply the database migrations:

   ```bash
   scripts/apply-migrations.sh
   ```

3. Download the Kaggle dataset's `car_prices.csv`, then stream it from this computer into Supabase with PostgreSQL's bulk-copy protocol:

   ```bash
   scripts/import-data.sh /absolute/path/to/car_prices.csv
   ```

4. Verify the remote tables, extensions, and indexes:

   ```bash
   scripts/check-schema.sh
   ```
