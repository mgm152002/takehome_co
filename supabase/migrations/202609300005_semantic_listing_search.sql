create or replace function public.search_semantic_vehicle_listings(
    query_embedding extensions.vector(384),
    page_number integer default 0,
    page_size integer default 100,
    match_threshold real default 0.55
)
returns table (
    id bigint,
    year smallint,
    make text,
    model text,
    "trim" text,
    body text,
    transmission text,
    vin text,
    state text,
    condition_score numeric,
    odometer bigint,
    color text,
    interior text,
    seller text,
    mmr numeric,
    selling_price numeric,
    sale_date timestamptz,
    match_type text,
    score real,
    has_next boolean,
    elapsed_ms double precision
)
language sql
volatile
set search_path = public, extensions
as $$
    with params as materialized (
        select
            greatest(coalesce(page_number, 0), 0) as requested_page,
            least(greatest(coalesce(page_size, 100), 1), 100) as requested_size,
            greatest(least(coalesce(match_threshold, 0.55), 1.0), 0.0) as threshold,
            clock_timestamp() as started_at
    ),
    nearest_profiles as materialized (
        -- Pure HNSW nearest-neighbor ordering with NO distance predicate in the
        -- scan: the >= threshold filter in the WHERE forces the planner to
        -- re-evaluate the distance on every candidate (~55ms vs ~0.7ms). Fetch
        -- the nearest 40 best-first, then apply the threshold afterward.
        select
            profiles.id,
            (1 - (profiles.embedding <=> query_embedding))::real as similarity
        from public.vehicle_profiles profiles
        where profiles.embedding is not null
        order by profiles.embedding <=> query_embedding, profiles.id
        limit 40
    ),
    profile_matches as materialized (
        select nearest_profiles.id, nearest_profiles.similarity
        from nearest_profiles
        cross join params
        where nearest_profiles.similarity >= params.threshold
        order by nearest_profiles.similarity desc, nearest_profiles.id
        limit 20
    ),
    ranked as materialized (
        -- A matched profile can map to thousands of listings (hot profiles have
        -- 2-3k). Sorting all 20 profiles' listings together is the dominant cost.
        -- Since the final result is capped at 500, no single profile can supply
        -- more than 500 rows, so cap per-profile first, then do the global sort.
        select capped.*
        from (
            select
                listings.*,
                profile_matches.similarity as score,
                row_number() over (
                    partition by listings.profile_id
                    order by listings.sale_date desc nulls last, listings.id
                ) as per_profile_rank
            from profile_matches
            join public.vehicle_listings listings
              on listings.profile_id = profile_matches.id
        ) capped
        where capped.per_profile_rank <= 500
        order by capped.score desc, capped.sale_date desc nulls last, capped.id
        limit 500
    ),
    numbered as materialized (
        select
            ranked.*,
            row_number() over (
                order by ranked.score desc, ranked.sale_date desc nulls last, ranked.id
            ) as result_number
        from ranked
    ),
    counted as materialized (
        select numbered.*, count(*) over () as total_results
        from numbered
    ),
    timing as materialized (
        select
            extract(epoch from (clock_timestamp() - params.started_at)) * 1000.0 as elapsed_ms
        from params
        cross join (select count(*) from counted) completed
    )
    select
        counted.id,
        counted.year,
        counted.make,
        counted.model,
        counted.trim,
        counted.body,
        counted.transmission,
        counted.vin,
        counted.state,
        counted.condition_score,
        counted.odometer,
        counted.color,
        counted.interior,
        counted.seller,
        counted.mmr,
        counted.selling_price,
        counted.sale_date,
        'SEMANTIC'::text as match_type,
        counted.score,
        (
            counted.total_results
            > least((params.requested_page + 1) * params.requested_size, 500)
        ) as has_next,
        timing.elapsed_ms
    from counted
    cross join params
    cross join timing
    where counted.result_number > params.requested_page * params.requested_size
      and counted.result_number
          <= least((params.requested_page + 1) * params.requested_size, 500)
    order by counted.result_number;
$$;
