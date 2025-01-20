#!/bin/bash

# Create the chain genesis files and initialize the validator node

# install dependencies
apt-get update && apt-get install jq -y && apt-get clean

cp /root/bin/gaiad /usr/local/bin
cd /root

gaiad config set client chain-id $CHAIN_ID
gaiad config set client keyring-backend test

# add the predefined keys
gaiad keys import-hex --keyring-backend test validator $VALIDATOR_KEY
gaiad keys import-hex --keyring-backend test relayer $RELAYER_KEY
gaiad keys import-hex --keyring-backend test faucet $FAUCET_KEY

# initialize the node
gaiad init validator --chain-id $CHAIN_ID --default-denom uatom

update_genesis() {
  file="/root/.gaia/config/genesis.json"
  jq "$1" $file > $file.tmp && mv $file.tmp $file
}

# increase block time
update_genesis '.consensus["params"]["block"]["time_iota_ms"]="6000"'

# update fee params
update_genesis '.app_state["feemarket"]["params"]["fee_denom"]="uatom"'
update_genesis '.app_state["feemarket"]["params"]["min_base_gas_price"]="0.005000000000000000"'
update_genesis '.app_state["feemarket"]["params"]["max_block_utilization"]="75000000"'

# add genesis accounts
gaiad genesis add-genesis-account validator 1500000000000uatom --keyring-backend test
gaiad genesis add-genesis-account relayer 1000000000000uatom --keyring-backend test
gaiad genesis add-genesis-account faucet 400000000000000uatom --keyring-backend test

# create validator genesis transaction
gaiad genesis gentx validator 1000000000000uatom --keyring-backend test \
  --chain-id $CHAIN_ID \
  --moniker "validator" \
  --commission-rate "0.10" \
  --commission-max-rate "0.20" \
  --commission-max-change-rate "0.01"

gaiad genesis collect-gentxs
gaiad genesis validate
