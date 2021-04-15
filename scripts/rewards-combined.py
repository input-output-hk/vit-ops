"""Usage: rewards.py [--network-magic=INT] [--state-dir=DIR] [--threshold=INT] [--db-user=STRING] [--db=STRING] [--db-host=STRING] [--slot=INT] [--pot=INT]

Options:
    --network-magic <magic>  network magic (specify 0 for mainnet) [default: 1097911063]
    --state-dir <dir>  state directory [default: ./state-node-testnet]
    --threshold <int>  minimum threshold of funds required to vote [default: 8000000000]
    --db-user <string>  database user [default: cexplorer]
    --db <string>  database [default: cexplorer]
    --db-host <string>  socket file for database connection [default: /run/postgresql]
    --slot <int>  slot to snapshot from [ default: None ]
    --pot <int>   total rewards available to split
"""


import binascii
import cbor2
import json
import subprocess
from docopt import docopt
from vitlib import VITBridge
from datetime import datetime
from math import floor
import itertools

arguments = docopt(__doc__)
pot = int(arguments["--pot"])

timestamp = int(datetime.timestamp(datetime.now().replace(microsecond=0, second=0, minute=0, tzinfo=None)))

bridge = VITBridge(arguments['--network-magic'], arguments['--state-dir'], arguments['--db'], arguments['--db-user'], arguments['--db-host'] )
slot = arguments["--slot"]

with open("genesis-template.json") as f:
    genesis = json.load(f)

all_funds = {}
vote_stake = {}
vote_rewards = {}


with open("finalRegs.json") as f:
    yoroi_dump = json.load(f)

valid_yoroi_keys = {}
for entry in yoroi_dump:
    badkey = entry["registration"]["meta"][0]["value"]["2"]
    valid_yoroi_keys[badkey] = entry["vKey"]

with open("recoverableNewFinal.json") as f:
    yoroi_dump = json.load(f)
for entry in yoroi_dump:
    badkey = entry["registration"]["meta"][0]["value"]["2"]
    valid_yoroi_keys[badkey] = entry["vKey"]


keys_yoroi = bridge.fetch_yoroi_registrations(slot, valid_yoroi_keys, rewards=True)
keys_fund3 = bridge.fetch_voting_keys(slot, rewards=True)

keys = { **keys_fund3, **keys_yoroi }

#bridge.gen_snapshot(slot)

total_stake = 0
for key,value in keys.items():
    stake = bridge.get_stake(key)
    if value in vote_stake:
        vote_stake[value] += stake
    else:
        vote_stake[value] = stake

# filter out any stake less than threshold
vote_stake = dict(filter(lambda elem: elem[1] >= int(arguments["--threshold"]), vote_stake.items()))

total_stake = sum(vote_stake.values())


for key, value in vote_stake.items():
    if int(arguments["--network-magic"]) == 0:
        prefix = "addr"
    else:
        prefix = "addr_test"
    address = bridge.prefix_bech32(prefix, key)
    if address in vote_rewards:
        vote_rewards[address] += floor(value / total_stake * pot)
    else:
        vote_rewards[address] = floor(value / total_stake * pot)

print(total_stake)
