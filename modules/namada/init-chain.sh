#!/bin/bash

# Create the chain genesis files and initialize the validator node

export NAMADA_GENESIS_TX_CHAIN_ID="$CHAIN_PREFIX"

# install dependencies
apt-get update && apt-get install jq busybox -y && apt-get clean

cd /root

# add the predefined keys
declare -A keys=(
  [validator]=$VALIDATOR_KEY
  [relayer]=$RELAYER_KEY
  [faucet]=$FAUCET_KEY
)

declare -A addresses

for alias in "${!keys[@]}"; do
  namadaw --pre-genesis add --value "${keys[$alias]}" --alias "$alias" --unsafe-dont-encrypt
done

for alias in "${!keys[@]}"; do
  addresses[$alias]=$(namadaw --pre-genesis find --addr --alias "$alias" | grep -o 'tnam[^"]*')
done

# create a genesis validator
est_output=$(namadac utils init-genesis-established-account --aliases validator --path /root/unsigned-transactions.toml)
EST_ADDRESS=$(echo $est_output | grep -o 'tnam[[:alnum:]]*')

namadac utils init-genesis-validator \
  --alias validator \
  --address $EST_ADDRESS \
  --path "/root/unsigned-transactions.toml" \
  --net-address "1.2.3.4:26656" \
  --commission-rate 0.05 \
  --max-commission-rate-change 0.01 \
  --email "validator@local.net" \
  --self-bond-amount 1000 \
  --unsafe-dont-encrypt

namadac utils sign-genesis-txs \
  --path "/root/unsigned-transactions.toml" \
  --output "/root/signed-transactions.toml" \
  --alias validator

# copy the (read-only) genesis template to a new directory where they can be edited
cp -a /root/genesis /root/ammended-genesis

# append the validator transaction to the genesis transactions.toml
echo "\n" >> /root/ammended-genesis/transactions.toml
cat /root/signed-transactions.toml >> /root/ammended-genesis/transactions.toml

# append genesis balances to the balances.toml
{
  echo "${addresses[validator]} = \"100000\""
  echo "$EST_ADDRESS = \"100000\""
  echo "${addresses[relayer]} = \"100000\""
  echo "${addresses[faucet]} = \"400000000\""
} >> /root/ammended-genesis/balances.toml

# extract the tx and vp checksums from the checksums.json file
TX_CHECKSUMS=$(jq -r 'to_entries[] | select(.key | startswith("tx")) | .value' /root/ammended-genesis/wasm/checksums.json | sed 's/.*\.\(.*\)\..*/"\1"/' | paste -sd "," -)
VP_CHECKSUMS=$(jq -r 'to_entries[] | select(.key | startswith("vp")) | .value' /root/ammended-genesis/wasm/checksums.json | sed 's/.*\.\(.*\)\..*/"\1"/' | paste -sd "," -)

# add them to parameters.toml allowlist
sed -i "s#tx_allowlist = \[\]#tx_allowlist = [$TX_CHECKSUMS]#" /root/ammended-genesis/parameters.toml
sed -i "s#vp_allowlist = \[\]#vp_allowlist = [$VP_CHECKSUMS]#" /root/ammended-genesis/parameters.toml

# create the chain configs
GENESIS_TIME=$(date -u -d "+$GENESIS_DELAY_MINS minutes" +"%Y-%m-%dT%H:%M:%S.000000000+00:00")
INIT_OUTPUT=$(namadac utils init-network \
  --genesis-time "$GENESIS_TIME" \
  --wasm-checksums-path /root/ammended-genesis/wasm/checksums.json \
  --wasm-dir /root/ammended-genesis/wasm \
  --chain-prefix $CHAIN_PREFIX \
  --templates-path /root/ammended-genesis \
  --consensus-timeout-commit 8s)

echo "$INIT_OUTPUT"
CHAIN_ID=$(echo "$INIT_OUTPUT" \
  | grep 'Derived chain ID:' \
  | awk '{print $4}')
echo "Chain id: $CHAIN_ID"

# start a local http server to serve the genesis files
mkdir -p /root/serve
mv ${CHAIN_ID}.tar.gz /root/serve/
cd /root/serve
busybox httpd -f -p 8000 &
SERVER_PID=$!

# wait for the server to start
sleep 2

export NAMADA_NETWORK_CONFIGS_SERVER="http://localhost:8000"
namadac utils join-network --chain-id $CHAIN_ID --genesis-validator validator

# set cors allowed origins to * in the config, since env variable method doesn't seem to work
sed -i 's#cors_allowed_origins = \[*.#cors_allowed_origins = ["\*"]#' /root/.local/share/namada/${CHAIN_ID}/config.toml

kill "$SERVER_PID"
