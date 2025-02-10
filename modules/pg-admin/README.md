# Pg-admin

A Pg-admin container which can be useful for providing a gui to inspect the contents of the `namada-indexer` and `masp-indexer` database contents.  

## Usage
```
[[modules]]
module_dir = "modules/pg-admin"
type = "aux"
```

In your web browser, navigate to the Pg-admin page (`http://localhost:8081` by default) and use the default credentials:
- email: `admin@namada.com`
- password: `namada`

These values can be changed in the docker-compose.yml file.  

Once logged in, to connect with one of the postgres databases, register a new server connection. Remember that any urls should be relative to the docker network; ie: to connect to the indexer's postgres db, use the url `http://postgres:5433` (user: 'postgres', password: 'password'). The values for hostname, port, user and password can be found (or changed) in the docker-compose.yml files for the indexer and masp-indexer.