{{
  config(
    schema = 'aave_lido_v3_ethereum',
    alias = 'base_supply',
    materialized = 'incremental',
    file_format = 'delta',
    incremental_strategy = 'merge',
    unique_key = ['transaction_type', 'token_address', 'tx_hash', 'evt_index'],
    incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
  )
}}

{{
  lending_aave_v3_compatible_supply(
    blockchain = 'ethereum',
    project = 'aave_lido',
    version = '3',
    decoded_contract_name = 'LidoPool',
    decoded_wrapped_token_gateway_name = 'LidoWrappedTokenGatewayV3'
  )
}}
