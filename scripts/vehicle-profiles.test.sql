do $$
declare
    expected_profiles bigint;
    actual_profiles bigint;
    refreshed_profiles bigint;
begin
    select count(*) into expected_profiles
    from (
        select lower(make), lower(model), lower(coalesce(body, ''))
        from public.vehicle_listings
        group by lower(make), lower(model), lower(coalesce(body, ''))
    ) distinct_profiles;

    select count(*) into actual_profiles
    from public.vehicle_profiles;

    if actual_profiles <> expected_profiles or actual_profiles = 0 then
        raise exception 'expected % vehicle profiles, found %', expected_profiles, actual_profiles;
    end if;

    if exists (
        select 1 from public.vehicle_listings where profile_id is null
    ) then
        raise exception 'every listing should be linked to a vehicle profile';
    end if;

    select public.refresh_vehicle_profiles() into refreshed_profiles;
    if refreshed_profiles <> expected_profiles then
        raise exception 'profile refresh should be repeatable';
    end if;
end
$$;

select 'vehicle profile tests passed' as result;
