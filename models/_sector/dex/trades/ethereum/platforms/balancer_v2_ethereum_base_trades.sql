{{
    config(
        schema = 'balancer_v2_ethereum',
        alias ='base_trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{
    balancer_compatible_v2_trades(
        blockchain = 'ethereum',
        project = 'balancer',
        version = '2',
        Vault_evt_Swap = 'Vault_evt_Swap'
    )
}}