# Osmosis local net

This module generates a one-validator osmosis chain.  

The `genesis.json` file is generated dynamically in the `init-chain.sh` script. You can make further modifications by following the pattern in the script.  

The chain includes genesis balances for a validator, relayer, and faucet account. There is also a 'pools' account which is used by the `init-xcs.sh` script (see below). You can view or change these keys in the `docker-compose.yml` file; if you change the relayer key, make sure you update your hermes instance accordingly. (**Note:** Hermes will require the key to be in the form of a mnemonic; so if you wish to use another relayer key make sure you have that available.)

### Crosschain swaps
You can enable crosschain swaps for use with Namada by deploying and initializing the wasm contracts in the `bytecode` directory; the `init-xcs.sh` script can be used to perform the necessary operations. This script makes some assumptions that your config setup matches the one at `{repo base}/examples/xcs.toml` due to some hardcoded values for denoms and channel ids. For step-by-step instructions on setting up and testing crosschain swaps, see `{repo base}/docs/xcs.md`.
