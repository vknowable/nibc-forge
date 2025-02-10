#!/bin/bash

# Create the chain genesis files and initialize the validator node
# Based on https://github.com/osmosis-labs/osmosis/blob/main/tests/localosmosis from the Osmosis repository

# install dependencies
apt-get update && apt-get install curl -y && apt-get clean
curl -sSLf "$(curl -sSLf https://api.github.com/repos/tomwright/dasel/releases/latest \
  | grep browser_download_url | grep linux_amd64 | grep -v .gz | cut -d\" -f 4)" -L -o dasel && chmod +x dasel
mv ./dasel /usr/local/bin/dasel

cd /root

osmosisd config set client chain-id $CHAIN_ID
osmosisd config set client keyring-backend test

# add the predefined keys
osmosisd keys import-hex --keyring-backend test validator $VALIDATOR_KEY
osmosisd keys import-hex --keyring-backend test relayer $RELAYER_KEY
osmosisd keys import-hex --keyring-backend test faucet $FAUCET_KEY
osmosisd keys import-hex --keyring-backend test pools $POOLS_KEY

# initialize the node
osmosisd init validator --chain-id $CHAIN_ID

# Genesis params from https://github.com/osmosis-labs/osmosis/blob/main/tests/localosmosis/scripts/setup.sh
edit_genesis () {
  GENESIS="/osmosis/.osmosisd/config/genesis.json"

  # Update staking module
  dasel put -t string -f $GENESIS '.app_state.staking.params.bond_denom' -v $DENOM
  # dasel put -t string -f $GENESIS '.app_state.staking.params.unbonding_time' -v '240s'

  # Update bank module
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[].description' -v 'Registered denom uion for local testing'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].denom_units.[].denom' -v 'uion'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].denom_units.[0].exponent' -v 0
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].base' -v 'uion'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].display' -v 'uion'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].name' -v 'uion'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[0].symbol' -v 'uion'

  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[].description' -v 'Registered base denom for local testing'
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].denom_units.[].denom' -v $DENOM
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].denom_units.[0].exponent' -v 0
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].base' -v $DENOM
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].display' -v $DENOM
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].name' -v $DENOM
  dasel put -t string -f $GENESIS '.app_state.bank.denom_metadata.[1].symbol' -v $DENOM

  # Update crisis module
  dasel put -t string -f $GENESIS '.app_state.crisis.constant_fee.denom' -v $DENOM

  # Update gov module
  dasel put -t string -f $GENESIS '.app_state.gov.voting_params.voting_period' -v '60s'
  dasel put -t string -f $GENESIS '.app_state.gov.params.min_deposit.[0].denom' -v $DENOM

  # Update epochs module
  dasel put -t string -f $GENESIS '.app_state.epochs.epochs.[1].duration' -v "60s"

  # Update poolincentives module
  dasel put -t string -f $GENESIS '.app_state.poolincentives.lockable_durations.[0]' -v "120s"
  dasel put -t string -f $GENESIS '.app_state.poolincentives.lockable_durations.[1]' -v "180s"
  dasel put -t string -f $GENESIS '.app_state.poolincentives.lockable_durations.[2]' -v "240s"
  dasel put -t string -f $GENESIS '.app_state.poolincentives.params.minted_denom' -v $DENOM

  # Update incentives module
  dasel put -t string -f $GENESIS '.app_state.incentives.lockable_durations.[0]' -v "1s"
  dasel put -t string -f $GENESIS '.app_state.incentives.lockable_durations.[1]' -v "120s"
  dasel put -t string -f $GENESIS '.app_state.incentives.lockable_durations.[2]' -v "180s"
  dasel put -t string -f $GENESIS '.app_state.incentives.lockable_durations.[3]' -v "240s"
  dasel put -t string -f $GENESIS '.app_state.incentives.params.distr_epoch_identifier' -v "hour"

  # Update mint module
  dasel put -t string -f $GENESIS '.app_state.mint.params.mint_denom' -v $DENOM
  dasel put -t string -f $GENESIS '.app_state.mint.params.epoch_identifier' -v "hour"

  # Update poolmanager module
  dasel put -t string -f $GENESIS '.app_state.poolmanager.params.pool_creation_fee.[0].denom' -v $DENOM

  # Update txfee basedenom
  dasel put -t string -f $GENESIS '.app_state.txfees.basedenom' -v $DENOM

  # Update wasm permission (Nobody or Everybody)
  dasel put -t string -f $GENESIS '.app_state.wasm.params.code_upload_access.permission' -v "Everybody"

  # Update concentrated-liquidity (enable pool creation)
  dasel put -t bool -f $GENESIS '.app_state.concentratedliquidity.params.is_permissionless_pool_creation_enabled' -v true
}

edit_genesis

# add genesis accounts
osmosisd add-genesis-account validator 1500000000000${DENOM} --keyring-backend test
osmosisd add-genesis-account relayer 1000000000000${DENOM} --keyring-backend test
osmosisd add-genesis-account faucet 400000000000000${DENOM},400000000000000uion,400000000000000stake,400000000000000uusdc,400000000000000uweth --keyring-backend test
osmosisd add-genesis-account pools 1000000000000${DENOM},1000000000000uion,1000000000000stake,1000000000000uusdc,1000000000000uweth --keyring-backend test

# create validator genesis transaction
osmosisd gentx validator 1000000000000${DENOM} --keyring-backend test \
  --chain-id $CHAIN_ID \
  --moniker "validator" \
  --commission-rate "0.10" \
  --commission-max-rate "0.20" \
  --commission-max-change-rate "0.01"

osmosisd collect-gentxs
