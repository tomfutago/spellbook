{{ config(
        schema = 'safe',
        alias = 'transactions_all',
        post_hook='{{ expose_spells(\'["arbitrum","avalanche_c","base","blast","bnb","celo","ethereum","fantom","gnosis","goerli","linea","mantle","optimism","polygon","scroll","worldchain","zkevm","zksync"]\',
                                "project",
                                "safe",
                                \'["kryptaki", "danielpartida", "safeintern"]\') }}'
        )
}}

{% set safe_transactions_models = [
 ref('safe_arbitrum_transactions')
,ref('safe_avalanche_c_transactions')
,ref('safe_base_transactions')
,ref('safe_blast_transactions')
,ref('safe_bnb_transactions')
,ref('safe_celo_transactions')
,ref('safe_ethereum_transactions')
,ref('safe_fantom_transactions')
,ref('safe_gnosis_transactions')
,ref('safe_goerli_transactions')
,ref('safe_linea_transactions')
,ref('safe_mantle_transactions')
,ref('safe_optimism_transactions')
,ref('safe_polygon_transactions')
,ref('safe_scroll_transactions')
,ref('safe_worldchain_transactions')
,ref('safe_zkevm_transactions')
,ref('safe_zksync_transactions')
,ref('safe_mantle_transactions')
] %}


SELECT *
FROM (
    {% for transactions_model in safe_transactions_models %}
    SELECT
        blockchain,
        block_date,
        block_month,
        block_time,
        block_number,
        tx_hash,
        address,
        to,
        value,
        gas,
        execution_gas_used,
        total_gas_used,
        tx_index,
        sub_traces,
        trace_address,
        success,
        error,
        code,
        input,
        output,
        method 
    FROM {{ transactions_model }}
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
)
