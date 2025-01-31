#!/bin/bash

# Container entry-point

if [ ! -f /root/.gaia/config/genesis.json ]; then
  echo "Initializing chain..."
  source /docker-entrypoint-scripts.d/init-chain.sh
else
  echo "(Re)starting node..."
fi

gaiad start \
  --home /root/.gaia \
  --pruning=nothing \
  --minimum-gas-prices="100${DENOM}" \
  --log_level=info \
  --api.enable \
  --api.enabled-unsafe-cors \
  --api.address="tcp://0.0.0.0:1317" \
  --rpc.laddr="tcp://0.0.0.0:26657" \
  --grpc.enable \
  --grpc.address="0.0.0.0:9090" \
  --consensus.create_empty_blocks_interval=6s
