# Testing Crosschain swaps

Steps for deploying a test environment with local osmosis, namada, and gaia chains and deploying the wasm contracts on osmosis to enable crosschain swaps from namada.

## Initial setup

Create a deployment:
```
./nibc-forge create --deployment-dir deployments/xcs --config-file examples/xcs.toml
```

Start the deployment:
```
./nibc-forge start --deployment-dir deployments/xcs
```

Wait for the IBC channels to be created (this can take up to 15 minutes); follow the Hermes logs to monitor progress:
```
docker logs -f xcs-hermes-1
```

After channel creation, hermes will start in relayer mode and the logs should switch to displaying regular operational messages (`client is valid` and `No evidence of misbehavior` are typical messages that show that hermes is done creating the channels).

Check the IBC channels that were created; you should see something similar to the following:
```
./nibc-forge ibc-channels --deployment-dir deployments/xcs
```
Output:
```
Listing created IBC channels for deployment in directory: deployments/xcs

namada-local.3ac7621ee21253199    <------>    gaia-local                    
channel-1                                     channel-1                     
07-tendermint-1                               07-tendermint-1               
Status: Success

osmosis-local    <------>    gaia-local   
channel-1                    channel-0    
07-tendermint-1                07-tendermint-0
Status: Success

osmosis-local                     <------>    namada-local.3ac7621ee21253199
channel-0                                     channel-0                     
07-tendermint-0                               07-tendermint-0               
Status: Success
```

## Prep
We first need to transfer some tokens from Namada and Gaia to Osmosis in preparation for deploying the contracts and creating the liquidity pool. We'll send them to the 'pools' address on osmosis (default: osmo1fs6q65e95hmegp5nwjw59zu205y602jtsjpx9)  

**Getting a shell in a container:**  
Execute the commands in the appropriate container (eg: namadac commands in the namada container, osmosisd commands in the osmosis container, etc.)  
To get a shell in a container, use the commands:
```
docker exec -it xcs-namada-node-1 /bin/bash
docker exec -it xcs-gaia-node-1 /bin/bash
docker exec -it xcs-osmosis-node-1 /bin/bash
```

IBC NAM from namada:
```
namadac ibc-transfer --source faucet --receiver osmo1jllfytsz4dryxhz5tl7u73v29exsf80vz52ucc --token nam --amount 100000 --channel-id channel-0
```

IBC uatom from gaia:
```
gaiad tx ibc-transfer transfer transfer channel-0 osmo1jllfytsz4dryxhz5tl7u73v29exsf80vz52ucc 100000000000uatom --from faucet --fees 500000uatom
```

Check the tokens arrived on osmosis:
```
# osmosisd q bank balances osmo1jllfytsz4dryxhz5tl7u73v29exsf80vz52ucc
balances:
- amount: "100000000000"
  denom: ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9
- amount: "100000000000"
  denom: ibc/F02F56D9D7F933009FEF49B7C115874E5A0C05CE2ED1E809C360F5D8F8A4ED4E
```

## Deploy the XCS contracts on osmosis and create the liquidity pool
Next, we need to deploy and configure the crosschain swap contracts on osmosis and create the liquidity pool. The script `init-xcs.sh` will perform these steps; run this script from inside the osmosis container:  

```
docker exec -it xcs-osmosis-node-1 /bin/bash
source /scripts/init-xcs.sh
```

**Note: This script may take 15 minutes or more to finish... after proposing the packet-forwarding-middleware, expect the script to pause with the message "Waiting for confirmation of pfm validation. This may take 10-15 minutes..." while the operation completes.**

Note: this script assumes a default setup as given in `examples/xcs.toml`; specifically it assumes:
- exactly three chains -- one osmosis, one namada and one gaia (in that order)
- the NAM address is tnam1q9gr66cvu4hrzm0sd5kmlnjje82gs3xlfg3v6nu7
- the gaia coin is uatom
- the channels were created so that their ids match the sample output above

If your setup differs, you can modify the script accordingly.  

When the script completes, it should display the values needed for the `--swap-contract` and `--pool-hop` arguments. To find these values later:

1. Display the crosschain_swaps contract address (assuming it was the third contract deployed):
```
osmosisd query wasm list-contract-by-code 3 -o json | jq -r '.contracts | [last][0]'
```

2. Assuming the liquidity pool has ID 1, and the ibc denom for uatom on osmosis is `ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9`, then `--pool-hop` will take the form:
```
--pool-hop "1:ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9"
```
## Make a crosschain swap

Test a crosschain swap from the namada container, swapping nam for uatom-on-namada (nam --> transfer/channel-1/uatom).
- `output-denom` is the denom of the desired asset *on namada*
- `local-recovery-addr` is any address on osmosis that you control
- `swap-contract` is the address of the crosschain_swaps contract on osmosis (which may be different in your case from the example below)
- `pool-hop` is the liquidity pool id and the ibc denom of uatom *on osmosis*

```
namadac osmosis-swap \
  --osmosis-rest-rpc http://osmosis-node:1317 \
  --source my_wallet \
  --token nam \
  --amount 100 \
  --channel-id channel-0 \
  --output-denom transfer/channel-1/uatom \
  --local-recovery-addr osmo1fs6q65e95hmegp5nwjw59zu205y602jtsjpx9u \
  --swap-contract osmo17p9rzwnnfxcjp32un9ug7yhhzgtkhvl9jfksztgw5uh69wac2pgs5yczr8 \
  --minimum-amount 1 \
  --target my_wallet \
  --pool-hop "1:ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9"
```

After a moment, check the balance of your target address. If the swap succeeded, you should see your tokens:
```
namadac balance --owner my_wallet --token transfer/channel-1/uatom
transfer/channel-1/uatom: 98911870
```

To make a shielded swap:
```
namadac osmosis-swap \
  --osmosis-rest-rpc http://osmosis-node:1317 \
  --source my_spendkey \
  --token nam \
  --amount 100 \
  --channel-id channel-0 \
  --output-denom transfer/channel-1/uatom \
  --local-recovery-addr osmo1fs6q65e95hmegp5nwjw59zu205y602jtsjpx9u \
  --swap-contract osmo17p9rzwnnfxcjp32un9ug7yhhzgtkhvl9jfksztgw5uh69wac2pgs5yczr8 \
  --minimum-amount 95 \
  --target-pa my_payment_addr \
  --overflow-addr my_second_wallet
  --pool-hop "1:ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9" \
  --gas-spending-key test-sk \
  --disposable-gas-payer \
  --gas-limit 500000
```
Where:
- `minimum-amount` is the amount that will be shielded to your payment address
- `overflow-addr` is a transparent address where any remainder will be sent. To maintain privacy, you should use a new transparent address that is not associated with any prior shielded activity. If you don't provide this argument, a new transparent address will be generated for you.

## Buidl
You're now ready to use the crosschain swaps environment for building or testing a front-end app:
- osmosis, namada, and gaia chains have their cometbft RPC port exposed; osmosis and gaia have their REST api port exposed also
- namada-indexer endpoint is available at `http://localhost:5001`
- namada-masp-indexer endpoint is available at `http://localhost:5000`
- pgadmin is available at `http://localhost:8081` with default username `admin@namada.com` and password `namada`; this is handy for directly inspecting the contents of the indexer and masp-indexer postgres databases. See the README in `modules/pgadmin` for details on how to set this up
