create or replace function public.search_vehicle_listings(
    query_text text,
    page_number integer default 0,
    page_size integer default 100
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
            lower(trim(coalesce(query_text, ''))) as query,
            greatest(coalesce(page_number, 0), 0) as requested_page,
            least(greatest(coalesce(page_size, 100), 1), 100) as requested_size,
            clock_timestamp() as started_at
    ),
    query_info as materialized (
        select
            params.*,
            websearch_to_tsquery('simple', params.query)
                || websearch_to_tsquery(
                    'simple',
                    regexp_replace(
                        regexp_replace(params.query, '([[:alpha:]])([[:digit:]])', '\1 \2', 'g'),
                        '([[:digit:]])([[:alpha:]])',
                        '\1 \2',
                        'g'
                    )
                ) as text_query
        from params
    ),
    recognized_make as materialized (
        select terms.normalized_term
        from public.suggestion_terms terms
        cross join query_info
        where terms.term_type = 'MAKE'
          and (' ' || regexp_replace(query_info.query, '[^a-z0-9]+', ' ', 'g') || ' ')
              like '% ' || terms.normalized_term || ' %'
        order by length(terms.normalized_term) desc
        limit 1
    ),
    exact_ranked as materialized (
        select
            listings.*,
            'EXACT'::text as match_type,
            least(
                1.0,
                ts_rank_cd(listings.search_vector, query_info.text_query, 32)::double precision * 0.70
                + case
                    when lower(listings.make) = (select normalized_term from recognized_make) then 0.15
                    else 0.0
                  end
                + case
                    when listings.normalized_title like '%' || query_info.query || '%' then 0.15
                    else 0.0
                  end
            )::real as score
        from public.vehicle_listings listings
        cross join query_info
        where length(query_info.query) >= 2
          and listings.search_vector @@ query_info.text_query
        order by score desc, listings.id
        limit 500
    ),
    fuzzy_ranked as materialized (
        select candidates.*
        from (
            select
                listings.*,
                'FUZZY'::text as match_type,
                least(
                    1.0,
                    0.35
                    + extensions.word_similarity(
                        trim(replace(query_info.query, recognized_make.normalized_term, '')),
                        lower(listings.model)
                      )::double precision * 0.45
                    + extensions.word_similarity(
                        query_info.query,
                        listings.normalized_title
                      )::double precision * 0.20
                )::real as score
            from public.vehicle_listings listings
            cross join query_info
            cross join recognized_make
            where not exists (select 1 from exact_ranked)
              and lower(listings.make) = recognized_make.normalized_term

            union all

            select
                listings.*,
                'FUZZY'::text as match_type,
                least(
                    1.0,
                    extensions.similarity(listings.normalized_title, query_info.query)::double precision * 0.65
                    + extensions.word_similarity(
                        query_info.query,
                        listings.normalized_title
                      )::double precision * 0.35
                )::real as score
            from public.vehicle_listings listings
            cross join query_info
            where not exists (select 1 from exact_ranked)
              and not exists (select 1 from recognized_make)
              and length(query_info.query) >= 2
              and listings.normalized_title OPERATOR(extensions.%) query_info.query
        ) candidates
        order by candidates.score desc, candidates.id
        limit 500
    ),
    ranked as materialized (
        select * from exact_ranked
        union all
        select * from fuzzy_ranked
    ),
    numbered as materialized (
        select
            ranked.*,
            row_number() over (order by ranked.score desc, ranked.id) as result_number,
            count(*) over () as total_results
        from ranked
    ),
    timing as materialized (
        select
            extract(epoch from (clock_timestamp() - query_info.started_at)) * 1000.0 as elapsed_ms
        from query_info
        cross join (select count(*) from numbered) completed
    )
    select
        numbered.id,
        numbered.year,
        numbered.make,
        numbered.model,
        numbered.trim,
        numbered.body,
        numbered.transmission,
        numbered.vin,
        numbered.state,
        numbered.condition_score,
        numbered.odometer,
        numbered.color,
        numbered.interior,
        numbered.seller,
        numbered.mmr,
        numbered.selling_price,
        numbered.sale_date,
        numbered.match_type,
        numbered.score,
        (
            numbered.total_results
            > least((query_info.requested_page + 1) * query_info.requested_size, 500)
        ) as has_next,
        timing.elapsed_ms
    from numbered
    cross join query_info
    cross join timing
    where numbered.result_number > query_info.requested_page * query_info.requested_size
      and numbered.result_number
          <= least((query_info.requested_page + 1) * query_info.requested_size, 500)
    order by numbered.result_number;
$$;
