#!/bin/bash

# Deploy and configure the contracts for crosschain swaps

# install dependencies
apt-get install jq -y
cp /scripts/jenv.sh /usr/local/bin/jenv && chmod +x /usr/local/bin/jenv

COMMON_ARGS="--keyring-backend test --chain-id $CHAIN_ID --fees 50000${DENOM} --gas auto --gas-adjustment 1.5 -y"

### deploy the contracts
echo -e "\nDeploying XCS contracts..."
osmosisd tx wasm store /root/bytecode/crosschain_registry.wasm --from pools $COMMON_ARGS
sleep 8
CROSSCHAIN_REGISTRY_CODE=$(osmosisd query wasm list-code -o json | jq -r '.code_infos[-1].code_id')
osmosisd tx wasm store /root/bytecode/swaprouter.wasm --from pools $COMMON_ARGS
sleep 8
SWAPROUTER_CODE=$(osmosisd query wasm list-code -o json | jq -r '.code_infos[-1].code_id')
osmosisd tx wasm store /root/bytecode/crosschain_swaps.wasm --from pools $COMMON_ARGS
sleep 8
CROSSCHAIN_SWAPS_CODE=$(osmosisd query wasm list-code -o json | jq -r '.code_infos[-1].code_id')

export POOLS_ADDRESS=$(osmosisd keys show pools --keyring-backend test -a)

# instantiate crosschain_registry
echo -e "\nInstantiating crosschain_registry contract..."
MSG=$(jenv -c '{"owner": $POOLS_ADDRESS}')
osmosisd tx wasm instantiate 1 "$MSG" --from pools --admin $POOLS_ADDRESS --label CrosschainRegistry -b sync $COMMON_ARGS
sleep 8
export CROSSCHAIN_REGISTRY_ADDR=$(osmosisd query wasm list-contract-by-code $CROSSCHAIN_REGISTRY_CODE -o json | jq -r '.contracts | [last][0]')

# instantiate swaprouter
echo -e "\nInstantiating swaprouter contract..."
MSG=$(jenv -c '{"owner": $POOLS_ADDRESS}')
osmosisd tx wasm instantiate 2 "$MSG" --from pools --admin $POOLS_ADDRESS --label SwapRouter -b sync $COMMON_ARGS
sleep 8
export SWAPROUTER_ADDR=$(osmosisd query wasm list-contract-by-code $SWAPROUTER_CODE -o json | jq -r '.contracts | [last][0]')

# instantiate crosschain_swaps
echo -e "\nInstantiating crosschain_swaps contract..."
MSG=$(jenv -c '{"governor": $POOLS_ADDRESS, "swap_contract": $SWAPROUTER_ADDR, "registry_contract": $CROSSCHAIN_REGISTRY_ADDR}')
osmosisd tx wasm instantiate 3 "$MSG" --from pools --admin $POOLS_ADDRESS --label CrosschainSwaps -b sync $COMMON_ARGS
sleep 8
CROSSCHAIN_SWAPS_ADDR=$(osmosisd query wasm list-contract-by-code $CROSSCHAIN_SWAPS_CODE -o json | jq -r '.contracts | [last][0]')

### configure the crosschain_registry:

# set the bech32 prefixes
echo -e "\nConfiguring crosschain_registry contract with bech32 prefixes..."
MSG='{"modify_bech32_prefixes": {"operations": [{"operation": "set","chain_name": "namada","prefix": "tnam"},{"operation": "set","chain_name": "osmosis","prefix": "osmo"},{"operation": "set","chain_name": "gaia","prefix": "cosmo"}]}}'
osmosisd tx wasm execute $CROSSCHAIN_REGISTRY_ADDR "$MSG" --from pools $COMMON_ARGS

sleep 8

# set the channel links
echo -e "\nConfiguring crosschain_registry contract with channel links..."
MSG='{"modify_chain_channel_links": {"operations": [{"operation": "set","source_chain": "namada","destination_chain": "osmosis","channel_id": "channel-0"},{"operation": "set","source_chain": "osmosis","destination_chain": "namada","channel_id": "channel-0"},{"operation": "set","source_chain": "namada","destination_chain": "gaia","channel_id": "channel-1"},{"operation": "set","source_chain": "gaia","destination_chain": "namada","channel_id": "channel-1"},{"operation": "set","source_chain": "gaia","destination_chain": "osmosis","channel_id": "channel-0"},{"operation": "set","source_chain": "osmosis","destination_chain": "gaia","channel_id": "channel-1"}]}}'
osmosisd tx wasm execute $CROSSCHAIN_REGISTRY_ADDR "$MSG" --from pools $COMMON_ARGS

sleep 8

# enable packet forwarding middleware
echo -e "\nConfiguring crosschain_registry contract to enable packet forwarding middleware..."
HASH=$(echo -n "transfer/channel-0/tnam1q9gr66cvu4hrzm0sd5kmlnjje82gs3xlfg3v6nu7" | sha256sum | awk '{print $1}' | tr 'a-f' 'A-F')
export NAM_DENOM="ibc/${HASH}"
echo "NAM_DENOM: $NAM_DENOM"

HASH=$(echo -n "transfer/channel-1/uatom" | sha256sum | awk '{print $1}' | tr 'a-f' 'A-F')
export GAIA_DENOM="ibc/${HASH}"
echo "GAIA_DENOM: $GAIA_DENOM"

echo -e "\nProposing pfm for namada..."
MSG=$(jenv -c '{"propose_pfm":{"chain":"namada"}}')
osmosisd tx wasm execute $CROSSCHAIN_REGISTRY_ADDR "$MSG" --amount "1${NAM_DENOM}" --from pools $COMMON_ARGS

sleep 8

echo -e "\nProposing pfm for gaia..."
MSG=$(jenv -c '{"propose_pfm":{"chain":"gaia"}}')
osmosisd tx wasm execute $CROSSCHAIN_REGISTRY_ADDR "$MSG" --amount "1${GAIA_DENOM}" --from pools $COMMON_ARGS

### wait for pfm validation... this can take a while
echo -e "\nWaiting for confirmation of pfm validation. This may take 10-15 minutes..."

echo "Waiting for pfm validation for namada..."
MSG=$(jenv -c '{"has_packet_forwarding":{"chain":"namada"}}')

while true; do
  res=$(osmosisd q wasm contract-state smart $CROSSCHAIN_REGISTRY_ADDR "$MSG" 2>/dev/null)

  if [[ $res == *"data: true"* ]]; then
    echo "Validation confirmed."
    break
  else
    echo "Validation pending... retrying in 60 seconds."
    sleep 60
  fi
done

echo "Waiting for pfm validation for gaia..."
MSG=$(jenv -c '{"has_packet_forwarding":{"chain":"gaia"}}')

while true; do
  res=$(osmosisd q wasm contract-state smart $CROSSCHAIN_REGISTRY_ADDR "$MSG" 2>/dev/null)

  if [[ $res == *"data: true"* ]]; then
    echo "Validation confirmed."
    break
  else
    echo "Validation pending... retrying in 60 seconds."
    sleep 60
  fi
done

### create liquidity pool
echo -e "\nCreating liquidity pool..."
JSON="{\"weights\": \"1$NAM_DENOM,1$GAIA_DENOM\",\"initial-deposit\": \"10000000000$NAM_DENOM,10000000000$GAIA_DENOM\",\"swap-fee\": \"0.001\",\"exit-fee\": \"0.000\"}"
echo -n $JSON > /root/liquidity_pool.json
osmosisd tx poolmanager create-pool --pool-file /root/liquidity_pool.json --from pools -b sync $COMMON_ARGS
echo "Done"

echo -e "\nCrosschain swaps are ready to be performed on namada"
echo "Use these arguments with the namadac osmosis-swaps command:"
echo "--swap-contract $CROSSCHAIN_SWAPS_ADDR"
echo "--pool-hop \"1:$GAIA_DENOM\""
