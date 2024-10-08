{{ config(
    schema='lido_liquidity_ethereum',
    alias = 'curve_wsteth_pufeth_pool',
    materialized = 'incremental',
    file_format = 'delta',
    incremental_strategy = 'merge',
    unique_key = ['pool', 'time'],
    incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.time')],
    post_hook='{{ expose_spells(blockchains = \'["ethereum"]\',
                                spell_type = "project",
                                spell_name = "lido_liquidity",
                                contributors = \'["pipistrella"]\') }}'
    )
}}

{% set project_start_date = '2024-03-23' %}



with

wsteth_in as (
select
    DATE_TRUNC('day', evt_block_time) as time,
    sum(cast(value as double))/1e18 as wsteth_in
from {{source('erc20_ethereum','evt_Transfer')}} t
{% if not is_incremental() %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE '{{ project_start_date }}'
 {% else %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE_TRUNC('day', NOW() - INTERVAL '1' day)
 {% endif %}
 and contract_address = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
 and to = 0xeeda34a377dd0ca676b9511ee1324974fa8d980d
group by 1
)

, wsteth_out as (
select
    DATE_TRUNC('day', evt_block_time) as time,
    -sum(cast(value as double))/1e18 as wsteth_out
from {{source('erc20_ethereum','evt_Transfer')}} t
{% if not is_incremental() %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE '{{ project_start_date }}'
 {% else %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE_TRUNC('day', NOW() - INTERVAL '1' day)
 {% endif %}
  and contract_address = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
  and "from" = 0xeeda34a377dd0ca676b9511ee1324974fa8d980d

group by 1
)

, wsteth_daily_balances as (
select time, sum(wsteth_in) wsteth_balance from (
select * from wsteth_in
union all
select * from wsteth_out
) group by 1
)

, wsteth_balances as (
select  time,
        sum(wsteth_balance) as wsteth
from wsteth_daily_balances b
group by 1
order by 1
)


, pufeth_in as (
select
    DATE_TRUNC('day', evt_block_time) as time,
    sum(cast(value as double))/1e18 as pufeth_in
from {{source('erc20_ethereum','evt_Transfer')}} t
 {% if not is_incremental() %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE '{{ project_start_date }}'
 {% else %}
 WHERE {{ incremental_predicate('evt_block_time') }}
 {% endif %}
 and contract_address = 0xD9A442856C234a39a81a089C06451EBAa4306a72
 and to = 0xeeda34a377dd0ca676b9511ee1324974fa8d980d
 group by 1
)

, pufeth_out as (
select
    DATE_TRUNC('day', evt_block_time) as time,
    -sum(cast(value as double))/1e18 as pufeth_out
from {{source('erc20_ethereum','evt_Transfer')}} t
 {% if not is_incremental() %}
 WHERE DATE_TRUNC('day', evt_block_time) >= DATE '{{ project_start_date }}'
 {% else %}
 WHERE {{ incremental_predicate('evt_block_time') }}
 {% endif %}
 and contract_address = 0xD9A442856C234a39a81a089C06451EBAa4306a72
 and "from" = 0xeeda34a377dd0ca676b9511ee1324974fa8d980d
 group by 1
)

, pufeth_daily_balances as (
select time, sum(pufeth_in) as pufeth_balance from (
select * from pufeth_in
union all
select * from pufeth_out
) group by 1
)

, pufeth_balances as (
select time, sum(pufeth_balance) pufeth
from pufeth_daily_balances
group by 1
order by 1
)


, pufeth_prices_daily AS (
    SELECT distinct
        DATE_TRUNC('day', minute) AS time,
        avg(price) AS price
    FROM {{source('prices','usd')}} p
    {% if not is_incremental() %}
    WHERE DATE_TRUNC('day', p.minute) >= DATE '{{ project_start_date }}'
    {% else %}
    WHERE {{ incremental_predicate('p.minute') }}
    {% endif %}
    and date_trunc('day', minute) < current_date
    and blockchain = 'ethereum'
    and contract_address = 0xD9A442856C234a39a81a089C06451EBAa4306a72
    group by 1
    union all
    SELECT distinct
        DATE_TRUNC('day', minute),
        last_value(price) over (partition by DATE_TRUNC('day', minute), contract_address ORDER BY  minute range between unbounded preceding AND unbounded following) AS price
    FROM {{source('prices','usd')}}
    WHERE date_trunc('day', minute) = current_date
    and blockchain = 'ethereum'
    and contract_address = 0xD9A442856C234a39a81a089C06451EBAa4306a72


)

, wsteth_prices_hourly AS (
    select time
    , lead(time,1, DATE_TRUNC('hour', now() + interval '1' hour)) over (order by time) as next_time
    , price
    from (
    SELECT distinct
        DATE_TRUNC('hour', minute) time
        , last_value(price) over (partition by DATE_TRUNC('hour', minute), contract_address ORDER BY  minute range between unbounded preceding AND unbounded following) AS price
    FROM {{source('prices','usd')}} p
    {% if not is_incremental() %}
    WHERE DATE_TRUNC('day', p.minute) >= DATE '{{ project_start_date }}'
    {% else %}
    WHERE {{ incremental_predicate('p.minute') }}
    {% endif %}
    and blockchain = 'ethereum'
    and contract_address = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0

))

, wsteth_prices_daily AS (
    SELECT distinct
        DATE_TRUNC('day', minute) AS time,
        avg(price) AS price
    FROM {{source('prices','usd')}} p
    {% if not is_incremental() %}
    WHERE DATE_TRUNC('day', p.minute) >= DATE '{{ project_start_date }}'
    {% else %}
    WHERE {{ incremental_predicate('p.minute') }}
    {% endif %}
    and date_trunc('day', minute) < current_date
    and blockchain = 'ethereum'
    and contract_address = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
    group by 1
    union all
    SELECT distinct
        DATE_TRUNC('day', minute),
        last_value(price) over (partition by DATE_TRUNC('day', minute), contract_address ORDER BY  minute range between unbounded preceding AND unbounded following) AS price
    FROM {{source('prices','usd')}}
    WHERE date_trunc('day', minute) = current_date
    and blockchain = 'ethereum'
    and contract_address = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0

)

, token_exchange_hourly as(
    select date_trunc('hour', evt_block_time) as time
        , sum(case when cast(sold_id as int) = int '0' then cast(tokens_sold as double) else cast(tokens_bought as double) end) as eth_amount_raw
    from {{source('puffer_ethereum','CurveStableSwapNG_evt_TokenExchange')}} c
    {% if not is_incremental() %}
    WHERE DATE_TRUNC('day', evt_block_time) >= DATE '{{ project_start_date }}'
    {% else %}
    WHERE {{ incremental_predicate('evt_block_time') }}
    {% endif %}
    group by 1

)

, trading_volume_hourly as (
    select t.time
        , t.eth_amount_raw * wp.price as volume_raw
    from token_exchange_hourly t
    left join wsteth_prices_hourly wp on t.time = wp.time
    order by 1
)

, trading_volume as (
    select distinct date_trunc('day', time) as time
        , sum(volume_raw)/1e18 as volume
    from trading_volume_hourly
    GROUP by 1
)

select 'ethereum curve pufETH:wstETH 0.04' as pool_name,
        0xeeda34a377dd0ca676b9511ee1324974fa8d980d as pool,
        'ethereum' as blockchain,
        'curve' as project,
        0.02 as fee,
        cast(b.time as date) as time,
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 as main_token,
        'wstETH' as main_token_symbol,
        0xD9A442856C234a39a81a089C06451EBAa4306a72 as paired_token,
        'pufETH' as paired_token_symbol,
        wsteth as main_token_reserve,
        coalesce(pufeth.pufeth, 0) as paired_token_reserve,
        coalesce(wstethp.price, 0)as main_token_usd_price,
        pufethp.price as paired_token_usd_price,
        v.volume as trading_volume
from wsteth_balances b
left join pufeth_balances pufeth on b.time = pufeth.time
left join wsteth_prices_daily wstethp on b.time = wstethp.time
left join pufeth_prices_daily pufethp on b.time = pufethp.time
left join trading_volume v on b.time = v.time

order by 1

