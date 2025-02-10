# Creating a deployment config

- `module_dir`: required; the path of the directory containing the module
- `type`: required; valid types are 'namada', 'gaia', 'osmosis', 'hermes' and 'aux'
- `rpc-hostname`: optional, but required if this module is a chain which you intend to connect via hermes.
- `relayer_key`: optional, but required if this module is a chain which you intend to connect via hermes. Note: for cosmos chains, the key must be provided in the form of a mnemonic. For namada chains, either mnemonic or raw private key is accepted.
- `hermes_template`: optional, this will default to the file at hermes_templates/{type}.toml
- `docker_env`: optional, provide a comma separated list of env variables you wish to set for the container (eg. to specify a different port or chain-id). Consult the module's docker-compose.yml file to see which variables can be set.

Note: the order in which you list the chains in your config file will effect the order in which the IBC channels are created, and the resulting channel ids. If you're using the 'hub' topology for Hermes (which is the default), the first chain in your config will be treated as the 'hub' chain and all other chains will be connected to it.