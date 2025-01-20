#!/bin/bash

# Container entry-point

if [ ! -f /root/.hermes/config.toml ]; then
  echo "Initializing IBC channels..."
  source /docker-entrypoint-scripts.d/init-channels.sh
fi

echo "Starting Hermes..."
hermes start
