#!/bin/bash

# Container entry-point

if [ ! -f /osmosis/.osmosis/config/genesis.json ]; then
  echo "Initializing chain..."
  source /docker-entrypoint-scripts.d/init-chain.sh
else
  echo "(Re)starting node..."
fi

# increase the block time; for some reason this resets to the default value whenever the node is stopped
sed -i 's#timeout_commit = ".*"#timeout_commit = "6000ms"#' /osmosis/.osmosisd/config/config.toml

osmosisd start \
  --home /osmosis/.osmosisd \
  --pruning=nothing \
  --log_level=info \
  --api.enable \
  --api.enabled-unsafe-cors \
  --api.address="tcp://0.0.0.0:1317" \
  --rpc.laddr="tcp://0.0.0.0:26657" \
  --grpc.enable \
  --grpc.address="0.0.0.0:9090" \
  --consensus.create_empty_blocks_interval=6s
