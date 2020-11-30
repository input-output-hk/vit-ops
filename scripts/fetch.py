"""Usage: fetch.py [--network-magic=INT] [--state-dir=DIR] [--threshold=INT] [--db-user=STRING] [--db=STRING] [--db-host=STRING] [--extra-funds=FILE]

Options:
    --network-magic <magic>  network magic (specify 0 for mainnet) [default: 1097911063]
    --state-dir <dir>  state directory [default: ./state-node-testnet]
    --threshold <int>  minimum threshold of funds required to vote [default: 8000000000]
    --db-user <string>  database user [default: cexplorer]
    --db <string>  database [default: cexplorer]
    --db-host <string>  socket file for database connection [default: /run/postgresql]
    --extra-funds <file>  extra-funds json file [ default: None ]
"""


import binascii
import cbor2
import json
import subprocess
from docopt import docopt
from vitlib import VITBridge
from cardanolib import CardanoCLIWrapper
from datetime import datetime
import itertools

arguments = docopt(__doc__)
extra_funds = arguments["--extra-funds"]

timestamp = int(datetime.timestamp(datetime.now().replace(microsecond=0, second=0, minute=0, tzinfo=None)))

bridge = VITBridge(arguments['--network-magic'], arguments['--state-dir'], arguments['--db'], arguments['--db-user'], arguments['--db-host'] )
cardano = CardanoCLIWrapper(arguments['--network-magic'], arguments['--state-dir'])

with open("genesis-template.json") as f:
    genesis = json.load(f)

if extra_funds:
    with open("extra_funds.json") as f:
        extra_funds = json.load(f)

all_funds = {}
vote_stake = {}
initial_funds = []

keys = bridge.fetch_voting_keys()
for key,value in keys.items():
    stake = bridge.get_stake(key)
    if value in vote_stake:
        vote_stake[value] += stake
    else:
        vote_stake[value] = stake


for key, value in vote_stake.items():
    if value > int(arguments["--threshold"]):
        all_funds[bridge.jcli_address(key)] = value

if extra_funds:
    all_funds.update(extra_funds)

loops = len(all_funds) // 100 + 1
for i in range(0, loops):
    start = i * 100
    if i == loops:
        end = loops * 100 + len(all_funds) % 100
    else:
        end = (i + 1) * 100
    funds = { "fund": [] }
    for key,value in dict(itertools.islice(all_funds.items(), start, end)).items():
        funds["fund"].append({"address": key, "value": value})
    initial_funds.append(funds)

genesis["initial"] = initial_funds
genesis["blockchain_configuration"]["block0_date"] = timestamp
print(json.dumps(genesis))
