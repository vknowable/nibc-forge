# NIBC Forge

Easily create and destroy local testing deployments for application development involving Namada <---> Cosmos SDK IBC functionality.  

A deployment consists of:
- A Namada local chain
- One or more Cosmos SDK local chain
- A Hermes instance
- Supporting start-up scripts, config etc.

## Getting Started
Commands are issued using the `nibc-forge` binary. The binary requires an expected directory structure (as seen in this repo); therefore the easiest way to use this project is to 
clone the repo place `nibc-forge` in the project root (you can build the binary or download it from the releases page).  

Subdirectories contain READMEs which give further info on their usage.
