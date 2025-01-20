# Namada local-net

This module generates a one-validator namada chain.  

The chain is generated dynamically from the included genesis files and binaries, so you can experiment with different parameters or binaries by replacing the files in this directory. (**Note:** Changing the contents of the NAM entry in `tokens.toml` will result in a different NAM token address, so make sure you account for that elsewhere if needed).  

The chain includes genesis balances for a validator, relayer, and faucet account. You can view or change these keys in the `docker-compose.yml` file; if you change the relayer key, make sure you update your hermes instance accordingly.
