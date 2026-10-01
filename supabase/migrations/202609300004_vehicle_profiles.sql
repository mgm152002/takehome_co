begin;
set local statement_timeout = '10min';

create index if not exists vehicle_listings_profile_identity_idx
    on public.vehicle_listings (
        lower(make),
        lower(model),
        lower(coalesce(body, ''))
    );

create or replace function public.refresh_vehicle_profiles()
returns bigint
language plpgsql
set search_path = public, extensions
as $$
declare
    profile_count bigint;
begin
    insert into public.vehicle_profiles (
        make,
        model,
        body,
        profile_text
    )
    select
        min(make),
        min(model),
        min(coalesce(body, '')),
        concat_ws(
            ' ',
            min(make),
            min(model),
            nullif(min(coalesce(body, '')), ''),
            case
                when lower(min(coalesce(body, ''))) like '%suv%'
                    then 'family utility sport utility vehicle'
                when lower(min(coalesce(body, ''))) like '%van%'
                    then 'family passenger cargo van'
                when lower(min(coalesce(body, ''))) like '%coupe%'
                     or lower(min(coalesce(body, ''))) like '%convertible%'
                    then 'sporty performance car'
                when lower(min(coalesce(body, ''))) like '%sedan%'
                    then 'passenger sedan'
                when lower(min(coalesce(body, ''))) like '%hatch%'
                    then 'compact practical hatchback'
                when lower(min(coalesce(body, ''))) like '%truck%'
                    then 'pickup work truck'
                else 'vehicle'
            end,
            case
                when lower(min(make)) in (
                    'audi', 'bmw', 'mercedes-benz', 'mercedes', 'mini', 'porsche', 'volkswagen'
                ) then 'German'
                when lower(min(make)) in (
                    'acura', 'honda', 'infiniti', 'lexus', 'mazda', 'mitsubishi',
                    'nissan', 'scion', 'subaru', 'suzuki', 'toyota'
                ) then 'Japanese'
                when lower(min(make)) in ('hyundai', 'kia') then 'Korean'
                when lower(min(make)) in (
                    'buick', 'cadillac', 'chevrolet', 'chrysler', 'dodge', 'ford',
                    'gmc', 'jeep', 'lincoln', 'ram', 'tesla'
                ) then 'American'
                else null
            end
        ) as profile_text
    from public.vehicle_listings
    group by lower(make), lower(model), lower(coalesce(body, ''))
    on conflict (lower(make), lower(model), lower(body)) do update
    set profile_text = excluded.profile_text,
        embedding = case
            when vehicle_profiles.profile_text = excluded.profile_text
                then vehicle_profiles.embedding
            else null
        end,
        updated_at = case
            when vehicle_profiles.profile_text = excluded.profile_text
                then vehicle_profiles.updated_at
            else now()
        end;

    delete from public.vehicle_profiles profiles
    where not exists (
        select 1
        from public.vehicle_listings listings
        where lower(listings.make) = lower(profiles.make)
          and lower(listings.model) = lower(profiles.model)
          and lower(coalesce(listings.body, '')) = lower(profiles.body)
    );

    update public.vehicle_listings listings
    set profile_id = profiles.id
    from public.vehicle_profiles profiles
    where lower(listings.make) = lower(profiles.make)
      and lower(listings.model) = lower(profiles.model)
      and lower(coalesce(listings.body, '')) = lower(profiles.body)
      and listings.profile_id is distinct from profiles.id;

    select count(*) into profile_count
    from public.vehicle_profiles;

    return profile_count;
end;
$$;

create or replace function public.search_vehicle_profiles(
    query_embedding extensions.vector(384),
    match_threshold real default 0.55,
    result_limit integer default 20
)
returns table (
    profile_id bigint,
    make text,
    model text,
    body text,
    similarity real
)
language sql
stable
set search_path = public, extensions
as $$
    select
        profiles.id,
        profiles.make,
        profiles.model,
        profiles.body,
        (1 - (profiles.embedding <=> query_embedding))::real as similarity
    from public.vehicle_profiles profiles
    where profiles.embedding is not null
      and 1 - (profiles.embedding <=> query_embedding)
          >= greatest(least(coalesce(match_threshold, 0.55), 1.0), 0.0)
    order by profiles.embedding <=> query_embedding, profiles.id
    limit least(greatest(coalesce(result_limit, 20), 1), 100);
$$;

select public.refresh_vehicle_profiles();

commit;
