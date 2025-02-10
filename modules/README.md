## Modules

Each subdirectory contains the composable 'modules' that can be used in your deployment. See the README in each subdirectory for more info on their usage.

### Adding or modifying modules
Think of each module directory as a 'template' that gets copied to your `deployment-dir` when you create a deployment. Modifying the contents of `deployment-dir/{module}` will affect the behavior of that deploymenet, whereas modifying the contents of a module here will affect all future deployments (since any changes will be copied when creating the deployment).  

Each module is really a self contained docker-compose project -- e.g: the `gaia` module contains everything needed to start a local gaia chain, such that it could be run using `cd gaia && docker compose up -d`.  

New modules can be added by creating a new subdirectory containing a `docker-compose.yml` file along with any other needed runtime files. When adding the module to your config, use `type = "aux"` to indicate that the module only needs to be started alongside the others and does not need to be accounted for by Hermes or any other modules.  

#### Adding a new chain module
Adding a new chain module could be done in the same manner, however keep in mind it might require modifications to the Hermes scripting or `create` command of the `nibc-forge` binary.
