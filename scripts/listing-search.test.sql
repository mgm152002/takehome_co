do $$
declare
    first_page_ids bigint[];
    repeated_page_ids bigint[];
begin
    if not exists (
        select 1
        from public.search_vehicle_listings('BMW M3', 0, 20)
        where make = 'BMW'
          and lower(model) = 'm3'
          and match_type = 'EXACT'
    ) then
        raise exception 'BMW M3 should return an exact BMW M3 result';
    end if;

    if not exists (
        select 1
        from public.search_vehicle_listings('Toyta Camry', 0, 20)
        where make = 'TOYOTA'
          and lower(model) = 'camry'
          and match_type = 'FUZZY'
    ) then
        raise exception 'Toyta Camry should fuzzy-match TOYOTA Camry';
    end if;

    if not exists (
        select 1
        from public.search_vehicle_listings('Ford F150', 0, 20)
        where make = 'FORD'
          and lower(replace(model, '-', '')) = 'f150'
    ) then
        raise exception 'Ford F150 should match a Ford F-150 variant';
    end if;

    perform count(*)
    from public.search_vehicle_listings($query$'; --$query$, 0, 20);

    if exists (
        select 1
        from public.search_vehicle_listings('BMW M3', 0, 20)
        where score < 0 or score > 1
    ) then
        raise exception 'scores must be normalized between zero and one';
    end if;

    if exists (
        select id from public.search_vehicle_listings('Toyota', 0, 10)
        intersect
        select id from public.search_vehicle_listings('Toyota', 1, 10)
    ) then
        raise exception 'adjacent pages must not overlap';
    end if;

    select array_agg(id) into first_page_ids
    from public.search_vehicle_listings('Toyota', 0, 10);

    select array_agg(id) into repeated_page_ids
    from public.search_vehicle_listings('Toyota', 0, 10);

    if first_page_ids is distinct from repeated_page_ids then
        raise exception 'repeated searches must return a stable page';
    end if;
end
$$;

select 'listing search tests passed' as result;
