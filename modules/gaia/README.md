# Gaia (Cosmos Hub) local net

This module generates a one-validator gaiad chain.  

The `genesis.json` file is generated dynamically, however it can easily be changed by adding to the `init-chain.sh` script according to the examples given.  

The chain includes genesis balances for a validator, relayer, and faucet account. You can view or change these keys in the `docker-compose.yml` file; if you change the relayer key, make sure you update your hermes instance accordingly. (**Note:** Hermes will require the key to be in the form of a mnemonic; so if you wish to use another relayer key make sure you have that available.)
