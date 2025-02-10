# Namada Masp-Indexer

### Usage
1. Unlike `namada-indexer`, it's not necessary to build the containers because we can pull the needed containers from Github container registry. To do so, run `docker compose pull` from this directory.
2. Add the module to your config:
```
[[modules]]
module_dir = "modules/namada-masp-indexer"
type = "aux"
```