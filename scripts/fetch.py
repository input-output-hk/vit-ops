import binascii
import cbor2
import json
import subprocess
from vitlib import VITBridge
from cardanolib import CardanoCLIWrapper

bridge = VITBridge(1097911063, "/home/sam/work/iohk/cardano-node/master/state-node-testnet", "cexplorer", "cexplorer", "/run/postgresql")
cardano = CardanoCLIWrapper(1097911063, "/home/sam/work/iohk/cardano-node/master/state-node-testnet")

vote_stake = {}

keys = bridge.fetch_voting_keys()
for key,value in keys.items():
    stake = bridge.get_stake(key)
    if value in vote_stake:
        vote_stake[value] += stake
    else:
        vote_stake[value] = stake

initial_funds = []
for key, value in vote_stake.items():
    initial_funds.append({"address": key, "value": value})

print(json.dumps(initial_funds))
