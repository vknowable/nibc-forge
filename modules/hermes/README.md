# Hermes

By including this module, upon starting your deployment IBC connections will automatically be formed between your deployment chains (the Hermes config will be generated based on the templates found in `{repo base}/hermes_templates). After opening the channels (which can take several minutes per connection), Hermes will start in relaying mode and you can proceed to send IBC transactions.  

## Usage
```
[[modules]]
module_dir = "modules/hermes"
type = "hermes"
hermes_template = "hermes_templates/hermes.toml"
docker_env = 'TOPOLOGY=mesh'
```

- `hermes_template`: the config template which defines the base options for hermes (log_level, etc.)
- `TOPOLOGY`: can be one of `mesh` or `hub` (default). Choosing mesh will open connections between all possible pairs of chains. Choosing hub will treat the first chain in your config as the 'hub' and open a connection between that chain and each additional chain.