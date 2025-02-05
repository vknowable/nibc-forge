#!/bin/bash

# Container entry-point

if [ ! -f /root/.local/share/namada/global-config.toml ]; then
  echo "Initializing chain..."
  source /docker-entrypoint-scripts.d/init-chain.sh
else
  echo "(Re)starting node..."
fi

NAMADA_LEDGER__COMETBFT__RPC__LADDR="tcp://0.0.0.0:26657" namadan ledger run
