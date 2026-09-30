do $$
declare
    result_count integer;
begin
    if not exists (
        select 1 from public.search_suggestions('bm', 8)
        where lower(term) = 'bmw'
    ) then
        raise exception 'bm should suggest BMW';
    end if;

    if not exists (
        select 1 from public.search_suggestions('toyota', 8)
        where lower(term) = 'toyota'
    ) then
        raise exception 'toyota should suggest TOYOTA';
    end if;

    if not exists (
        select 1 from public.search_suggestions('Toyta', 8)
        where lower(term) = 'toyota'
    ) then
        raise exception 'Toyta should fuzzy-match TOYOTA';
    end if;

    if exists (select 1 from public.search_suggestions(' ', 8)) then
        raise exception 'blank input should return no suggestions';
    end if;

    select count(*) into result_count
    from public.search_suggestions('to', 100);

    if result_count <> 8 then
        raise exception 'suggestions must be capped at eight, got %', result_count;
    end if;
end
$$;

select 'suggestion tests passed' as result;
