# NIBC Forge

Easily create and destroy local testing deployments for application development involving Namada <---> Cosmos SDK IBC functionality. Use this to quickly setup multiple local chains and automatically create the IBC channels in a ready-use-state, so you can get started on your IBC-compatible front-end. 

A deployment consists of:
- A Namada local chain
- One or more Cosmos SDK local chain
- A Hermes instance
- Other supporting processes like namada-indexer or namada-masp-indexer
- Supporting start-up scripts, config etc.

## Prerequisites
You must have a recent version of Docker which includes the `docker compose` commands (not the older standalone `docker-compose`).

## Getting Started
Commands are issued using the `nibc-forge` binary. Build it with:
```
cargo build
```

Basic operation goes like this:
1. Create a deployment config-file that lists the 'modules' you wish to include (see the examples in the `examples` directory)
2. Choose a directory to create the deployment in; for example `deployments/testnet`
3. Create the deployment: `nibc-forge create --deployment-dir deployments/testnet --config-file examples/example-spec.toml`
4. Start the deployment: `nibc-forge start --deployment-dir deployments/testnet`
5. Allow the hermes container time to setup the IBC channels; you can watch the progress by following the logs: `docker logs -f {hermes container name}`
6. List the created IBC channel info: `nibc-forge ibc-channels --deployment-dir deployments/testnet`
7. To get a shell in one of the containers (to send transactions for example): `docker exec -it {container name} /bin/bash`
8. To stop all deployment containers: `nibc-forge stop --deployment-dir deployments/testnet`
9. To stop and delete all deployment containers, volumes, networks etc: `nibc-forge clean --deployment-dir deployments/testnet`

Further info specific to each module is found in the module's README (`modules` directory)
