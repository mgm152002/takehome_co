begin;

update public.vehicle_profiles
set embedding = (
    '[' || '1,' || repeat('0,', 382) || '0]'
)::extensions.vector
where id = (select min(id) from public.vehicle_profiles);

update public.vehicle_profiles
set embedding = (
    '[' || '0,1,' || repeat('0,', 381) || '0]'
)::extensions.vector
where id = (
    select min(id) from public.vehicle_profiles
    where id > (select min(id) from public.vehicle_profiles)
);

do $$
declare
    query_embedding extensions.vector(384) := (
        '[' || '1,' || repeat('0,', 382) || '0]'
    )::extensions.vector;
    expected_profile_id bigint;
begin
    select min(id) into expected_profile_id
    from public.vehicle_profiles;

    if (
        select profile_id
        from public.search_vehicle_profiles(query_embedding, 0.55, 10)
        limit 1
    ) is distinct from expected_profile_id then
        raise exception 'vector profile search should return the closest profile first';
    end if;

    if not exists (
        select 1
        from public.search_semantic_vehicle_listings(query_embedding, 0, 10, 0.55) results
        join public.vehicle_listings listings on listings.id = results.id
        where listings.profile_id = expected_profile_id
          and results.match_type = 'SEMANTIC'
    ) then
        raise exception 'semantic listing search should return listings from the closest profile';
    end if;

    if exists (
        select 1
        from public.search_semantic_vehicle_listings(null, 0, 10, 0.55)
    ) then
        raise exception 'missing embeddings should degrade to no semantic results';
    end if;
end
$$;

rollback;

select 'semantic search tests passed' as result;
