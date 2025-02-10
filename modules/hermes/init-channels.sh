#!/bin/bash

# Generate the Hermes config and initialize the channels

# install dependencies
apt-get update && apt-get install jq yq curl -y && apt-get clean

cp /root/bin/* /usr/local/bin
cd /root

# this file contains a list of chains to be connected; the first chain is the 'hub' chain that will be connected to all other chains
# it is generated from the provided config file by the 'nibc-forge create' command
# for each chain, lists the node hostname, relayer key, and chain type
echo "Reading chainlist.json..."
CHAIN_HOSTS=$(cat /root/chainlist.json | jq -r .[].hostname)

# for each chain, verify that chain has reached block 3 and get the chain id. if not, skip the chain (timeout after 2 minutes)
CHAIN_IDS=""

for HOSTNAME in $CHAIN_HOSTS; do
  echo "Waiting for chain at $HOSTNAME to be available..."
  count=0
  while true; do
    query=$(curl -s $HOSTNAME:26657/status)
    height=$(echo $query | jq -r .result.sync_info.latest_block_height)
    if [[ -n "$height" && "$height" -ge 3 ]]; then
      CHAIN_ID=$(echo $query | jq -r .result.node_info.network)
      echo "Found chain id $CHAIN_ID"
      CHAIN_IDS+=" $CHAIN_ID"
      break
    fi
    if [[ "$count" -ge 60 ]]; then
      # timeout after 2 minutes
      echo "Failed to get chain id from $HOSTNAME after 2 minutes; skipping..."
      CHAIN_IDS+=" none"
      break
    fi
    sleep 2
    echo "."
    ((count++))
  done
done

# copy the hermes config template to the expected location
mkdir -p /root/.hermes
cp /root/config.toml /root/.hermes/config.toml

# for each chain: query the fee denom, update the hermes config, and add the relayer key
i=0
for HOSTNAME in $CHAIN_HOSTS; do
  CHAIN_IDS_ARRAY=($CHAIN_IDS)
  CHAIN_ID=${CHAIN_IDS_ARRAY[$i]}

  if [[ "${CHAIN_ID}" == "none" ]]; then
    continue
  elif [[ -z "${CHAIN_ID}" ]]; then
    break
  fi

  # query the node for the fee token denom
  CHAIN_TYPE=$(cat /root/chainlist.json | jq -r .[$i].type)
  if [[ "${CHAIN_TYPE}" == "namada" ]]; then
    nam_borsh=$(curl -s curl -s "http://$HOSTNAME:26657/abci_query?path=\"/shell/native_token\"&prove=false" | jq -r .result.response.value)
    DENOM=$(addr-decode $nam_borsh)
  elif [[ "${CHAIN_TYPE}" == "gaia" ]]; then
    DENOM=$(curl -s "http://$HOSTNAME:1317/feemarket/v1/params" | jq -r .params.fee_denom)
  elif [[ "${CHAIN_TYPE}" == "osmosis" ]]; then
    DENOM=$(curl -s "http://$HOSTNAME:1317/osmosis/txfees/v1beta1/base_denom" | jq -r .base_denom)
  fi

  # update the hermes config
  sed -i \
    -e "s|CHAIN_${i}|${CHAIN_ID}|" \
    -e "s|HOST_${i}|${HOSTNAME}|" \
    -e "s|DENOM_${i}|${DENOM}|" \
    -e "s|KEY_${i}|relayer${i}|" \
    /root/.hermes/config.toml
  
  # add the relayer key
  RELAYER_KEY=$(cat /root/chainlist.json | jq -r .[$i].key)
  if [[ "${CHAIN_TYPE}" == "namada" ]]; then
    # namada supports both raw keys and mnemonics. if the relayer_key contains a space, it's assumed to be a mnemonic
    if [[ "$RELAYER_KEY" =~ \  ]]; then
      echo $RELAYER_KEY | namadaw --pre-genesis derive --alias relayer${i} --unsafe-dont-encrypt
    else
      namadaw --pre-genesis add --value $RELAYER_KEY --alias relayer${i} --unsafe-dont-encrypt
    fi
    hermes keys add --chain $CHAIN_ID --key-file /root/.local/share/namada/pre-genesis/wallet.toml
  else
    # cosmos chains only support mnemonics
    echo "$RELAYER_KEY" | hermes keys add --chain $CHAIN_ID --mnemonic-file /dev/stdin
  fi
  
  # if the chain type is namada, run this dummy query to force the MASP params download ahead of time
  # otherwise, it may appear unexpectedly in later log output, causing invalid json structure
  if [[ "${CHAIN_TYPE}" == "namada" ]]; then
    hermes query channels --chain $CHAIN_ID
  fi

  ((i++))
done

CHAIN_IDS_ARRAY=($CHAIN_IDS)
num_chains=${#CHAIN_IDS_ARRAY[@]}

# depending on the value of the TOPOLOGY variable, connect the chains either in a mesh or hub-and-spoke manner
# mesh: establish ibc connections between all chains
# hub: (default) establish ibc connections between the first chain and all other chains

if [ "$TOPOLOGY" == "mesh" ]; then
  # initialize channels between all chains (mesh topology)
  for ((i=0; i<num_chains-1; i++)); do
    for ((j=i+1; j<num_chains; j++)); do
      echo "Creating channel between ${CHAIN_IDS_ARRAY[i]} and ${CHAIN_IDS_ARRAY[j]}... this may take 3 to 5 minutes"
      log_file="/root/.hermes/${CHAIN_IDS_ARRAY[i]}_${CHAIN_IDS_ARRAY[j]}.log"
      json_file="/root/.hermes/${CHAIN_IDS_ARRAY[i]}_${CHAIN_IDS_ARRAY[j]}.json"
      
      hermes --json create channel --a-chain ${CHAIN_IDS_ARRAY[i]} --b-chain ${CHAIN_IDS_ARRAY[j]} --a-port transfer --b-port transfer --new-client-connection --yes > $log_file
      cat $log_file

      # save the last json object in the log file (which holds the channel creation result) to a json file for easy reference later
      cat $log_file | jq -s '.[-1]' > $json_file
    done
  done

else
  # initialize the channels between the first chain (chain 0) and all other chains (hub and spoke topology)
  i=1
  for CHAIN in "${CHAIN_IDS_ARRAY[@]:1}"; do
    echo "Creating channel between ${CHAIN_IDS_ARRAY[0]} and ${CHAIN_IDS_ARRAY[i]}... this may take 3 to 5 minutes"
    log_file="/root/.hermes/${CHAIN_IDS_ARRAY[0]}_${CHAIN_IDS_ARRAY[i]}.log"
    json_file="/root/.hermes/${CHAIN_IDS_ARRAY[0]}_${CHAIN_IDS_ARRAY[i]}.json"
    hermes --json create channel --a-chain ${CHAIN_IDS_ARRAY[0]} --b-chain ${CHAIN_IDS_ARRAY[i]} --a-port transfer --b-port transfer --new-client-connection --yes > $log_file
    cat $log_file

    # save the json result
    cat $log_file | jq -s '.[-1]' > $json_file
    ((i++))
  done
fi
