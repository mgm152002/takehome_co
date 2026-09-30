create or replace function public.refresh_suggestion_terms()
returns bigint
language plpgsql
set search_path = public, extensions
as $$
declare
    refreshed_count bigint;
begin
    truncate table public.suggestion_terms restart identity;

    insert into public.suggestion_terms (
        term,
        normalized_term,
        term_type,
        frequency
    )
    select term, normalized_term, term_type, frequency
    from (
        select
            min(make) as term,
            lower(make) as normalized_term,
            'MAKE' as term_type,
            count(*) as frequency
        from public.vehicle_listings
        group by lower(make)

        union all

        select
            min(model) as term,
            lower(model) as normalized_term,
            'MODEL' as term_type,
            count(*) as frequency
        from public.vehicle_listings
        group by lower(model)

        union all

        select
            min(trim) as term,
            lower(trim) as normalized_term,
            'TRIM' as term_type,
            count(*) as frequency
        from public.vehicle_listings
        where trim is not null
        group by lower(trim)

        union all

        select
            min(make) || ' ' || min(model) as term,
            lower(make || ' ' || model) as normalized_term,
            'COMBINATION' as term_type,
            count(*) as frequency
        from public.vehicle_listings
        group by lower(make || ' ' || model)
    ) terms
    where normalized_term <> '';

    get diagnostics refreshed_count = row_count;
    return refreshed_count;
end;
$$;

create or replace function public.search_suggestions(
    query_text text,
    result_limit integer default 8
)
returns table (
    term text,
    term_type text,
    score real
)
language sql
stable
set search_path = public, extensions
as $$
    with input as (
        select
            lower(trim(coalesce(query_text, ''))) as query,
            least(greatest(coalesce(result_limit, 8), 1), 8) as max_results
    ),
    prefix_matches as (
        select
            suggestions.term,
            suggestions.term_type,
            suggestions.normalized_term,
            suggestions.frequency,
            case
                when suggestions.normalized_term = input.query then 1.0
                else greatest(0.8, extensions.similarity(suggestions.normalized_term, input.query))
            end as relevance,
            0 as match_tier
        from public.suggestion_terms suggestions
        cross join input
        where length(input.query) >= 2
          and suggestions.normalized_term like input.query || '%'
        order by relevance desc, suggestions.frequency desc
        limit (select max_results from input)
    ),
    fuzzy_matches as (
        select
            suggestions.term,
            suggestions.term_type,
            suggestions.normalized_term,
            suggestions.frequency,
            extensions.similarity(suggestions.normalized_term, input.query) as relevance,
            1 as match_tier
        from public.suggestion_terms suggestions
        cross join input
        where length(input.query) >= 2
          and suggestions.normalized_term OPERATOR(extensions.%) input.query
          and suggestions.normalized_term not like input.query || '%'
        order by relevance desc, suggestions.frequency desc
        limit (select max_results from input)
    )
    select matches.term, matches.term_type, matches.relevance::real as score
    from (
        select * from prefix_matches
        union all
        select * from fuzzy_matches
    ) matches
    order by matches.match_tier, matches.relevance desc, matches.frequency desc, matches.normalized_term
    limit (select max_results from input);
$$;

select public.refresh_suggestion_terms();
