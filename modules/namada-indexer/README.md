# Namada Indexer

### Usage
1. **In another directory** e.g. your home directory, clone the [namada-indexer](https://github.com/anoma/namada-indexer) repo and build the containers:
```
cd ~
git clone https://github.com/anoma/namada-indexer && cd namada-indexer
git checkout <latest tagged release>
docker compose build
```

2. Add the module to your config file. Make sure you specify the type as 'aux': 
```
[[modules]]
module_dir = "modules/namada-indexer"
type = "aux"
```