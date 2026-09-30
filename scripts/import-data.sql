begin;
set local statement_timeout = '10min';

create temporary table staging_vehicle_listings (
    year text,
    make text,
    model text,
    trim text,
    body text,
    transmission text,
    vin text,
    state text,
    condition text,
    odometer text,
    color text,
    interior text,
    seller text,
    mmr text,
    sellingprice text,
    saledate text
) on commit drop;

\copy staging_vehicle_listings from pstdin with (format csv, header true)

truncate table public.vehicle_listings restart identity;

insert into public.vehicle_listings (
    year, make, model, trim, body, transmission, vin, state,
    condition_score, odometer, color, interior, seller, mmr,
    selling_price, sale_date
)
select
    case when trim(year) ~ '^[0-9]{4}$' then trim(year)::smallint end,
    upper(trim(make)),
    trim(model),
    nullif(trim(trim), ''),
    nullif(trim(body), ''),
    nullif(lower(trim(transmission)), ''),
    nullif(upper(trim(vin)), ''),
    nullif(upper(trim(state)), ''),
    case when trim(condition) ~ '^[0-9]+([.][0-9]+)?$' then trim(condition)::numeric end,
    case when trim(odometer) ~ '^[0-9]+([.][0-9]+)?$' then round(trim(odometer)::numeric)::bigint end,
    nullif(lower(trim(color)), ''),
    nullif(lower(trim(interior)), ''),
    nullif(trim(seller), ''),
    case when trim(mmr) ~ '^[0-9]+([.][0-9]+)?$' then trim(mmr)::numeric end,
    case when trim(sellingprice) ~ '^[0-9]+([.][0-9]+)?$' then trim(sellingprice)::numeric end,
    case
        when trim(saledate) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then trim(saledate)::timestamptz
        when trim(saledate) ~ '^[A-Za-z]{3} [A-Za-z]{3} [0-9]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}'
            then to_timestamp(substring(trim(saledate) from 5 for 20), 'Mon DD YYYY HH24:MI:SS')
        else null
    end
from staging_vehicle_listings
where trim(make) <> ''
  and trim(model) <> ''
  and trim(year) ~ '^[0-9]{4}$'
  and trim(year)::integer between 1885 and 2100;

do $$
begin
    if not exists (select 1 from public.vehicle_listings) then
        raise exception 'import produced zero valid rows';
    end if;
end
$$;

update public.dataset_metadata
set version = version + 1,
    row_count = (select count(*) from public.vehicle_listings),
    updated_at = now()
where singleton = true;

commit;

select version, row_count, updated_at
from public.dataset_metadata
where singleton = true;
