create schema if not exists extensions;

create extension if not exists pg_trgm with schema extensions;
create extension if not exists vector with schema extensions;

create table if not exists public.vehicle_profiles (
    id bigint generated always as identity primary key,
    make text not null,
    model text not null,
    body text not null default '',
    profile_text text not null,
    embedding extensions.vector(384),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists vehicle_profiles_identity_idx
    on public.vehicle_profiles (lower(make), lower(model), lower(body));

create table if not exists public.vehicle_listings (
    id bigint generated always as identity primary key,
    year smallint,
    make text not null,
    model text not null,
    trim text,
    body text,
    transmission text,
    vin text,
    state text,
    condition_score numeric(5, 2),
    odometer bigint,
    color text,
    interior text,
    seller text,
    mmr numeric(12, 2),
    selling_price numeric(12, 2),
    sale_date timestamptz,
    profile_id bigint references public.vehicle_profiles(id) on delete set null,
    search_vector tsvector generated always as (
        setweight(to_tsvector('simple', coalesce(make, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(model, '')), 'A') ||
        setweight(to_tsvector('simple', coalesce(trim, '')), 'B') ||
        setweight(to_tsvector('simple', coalesce(body, '')), 'B')
    ) stored,
    normalized_title text generated always as (
        lower(trim(
            coalesce(year::text, '') || ' ' ||
            coalesce(make, '') || ' ' ||
            coalesce(model, '') || ' ' ||
            coalesce(trim, '') || ' ' ||
            coalesce(body, '')
        ))
    ) stored,
    created_at timestamptz not null default now(),
    constraint vehicle_listings_year_check check (year is null or year between 1885 and 2100)
);

create index if not exists vehicle_listings_search_idx
    on public.vehicle_listings using gin (search_vector);
create index if not exists vehicle_listings_title_trgm_idx
    on public.vehicle_listings using gin (normalized_title extensions.gin_trgm_ops);
create index if not exists vehicle_listings_make_idx
    on public.vehicle_listings (lower(make));
create index if not exists vehicle_listings_model_idx
    on public.vehicle_listings (lower(model));
create index if not exists vehicle_listings_profile_idx
    on public.vehicle_listings (profile_id);

create index if not exists vehicle_profiles_embedding_idx
    on public.vehicle_profiles using hnsw (embedding extensions.vector_cosine_ops)
    where embedding is not null;

create table if not exists public.suggestion_terms (
    id bigint generated always as identity primary key,
    term text not null,
    normalized_term text not null,
    term_type text not null check (term_type in ('MAKE', 'MODEL', 'TRIM', 'COMBINATION')),
    frequency bigint not null default 1 check (frequency > 0),
    created_at timestamptz not null default now(),
    unique (term_type, normalized_term)
);

create index if not exists suggestion_terms_prefix_idx
    on public.suggestion_terms (normalized_term text_pattern_ops);
create index if not exists suggestion_terms_trgm_idx
    on public.suggestion_terms using gin (normalized_term extensions.gin_trgm_ops);

create table if not exists public.dataset_metadata (
    singleton boolean primary key default true check (singleton),
    version bigint not null default 0,
    row_count bigint not null default 0,
    updated_at timestamptz not null default now()
);

insert into public.dataset_metadata (singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.vehicle_listings enable row level security;
alter table public.vehicle_profiles enable row level security;
alter table public.suggestion_terms enable row level security;
alter table public.dataset_metadata enable row level security;
