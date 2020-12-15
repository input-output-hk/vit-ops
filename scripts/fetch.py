#!/usr/bin/env python
"""Usage: fetch.py [--network-magic=INT] [--state-dir=DIR] [--threshold=INT] [--db-user=STRING] [--db=STRING] [--db-host=STRING] [--extra-funds=FILE] [--slot=INT]

Options:
    --network-magic <magic>  network magic (specify 0 for mainnet) [default: 1097911063]
    --state-dir <dir>        state directory [default: ./state-node-testnet]
    --threshold <int>        minimum threshold of funds required to vote [default: 8000000000]
    --db-user <string>       database user [default: cexplorer]
    --db <string>            database [default: cexplorer]
    --db-host <string>       socket file for database connection [default: /run/postgresql]
    --extra-funds <file>     extra-funds json file [ default: None ]
    --slot <int>             slot to snapshot from [ default: None ]
"""

import json
from docopt import docopt
from vitlib import VITBridge, time_delta_to_str
from datetime import datetime
import itertools
import time
import sys

arguments = docopt(__doc__)
extra_funds = arguments["--extra-funds"]
slot = arguments["--slot"]

print(
    "Fetching cardano blockchain data for encoding to catalyst block0.bin",
    file=sys.stderr,
)

timestamp = int(
    datetime.timestamp(
        datetime.now().replace(microsecond=0, second=0, minute=0, tzinfo=None)
    )
)

bridge = VITBridge(
    arguments["--network-magic"],
    arguments["--state-dir"],
    arguments["--db"],
    arguments["--db-user"],
    arguments["--db-host"],
)

with open("genesis-template.json") as f:
    genesis = json.load(f)

if extra_funds:
    with open(extra_funds) as f:
        extra_funds = json.load(f)

all_funds = {}
vote_stake = {}
initial_funds = []

keys = bridge.fetch_voting_keys(slot)
timer = time.time()
for (i, (key, value)) in enumerate(keys.items(), start=1):
    stake = bridge.get_stake(key, slot)
    if value in vote_stake:
        vote_stake[value] += stake
    else:
        vote_stake[value] = stake
    print(
        f"\r    Processing vote stake {i} of {len(keys.items())}",
        end="",
        file=sys.stderr,
    )
print(f" [{time_delta_to_str(time.time() - timer)}]", file=sys.stderr)

timer = time.time()
for (i, (key, value)) in enumerate(vote_stake.items(), start=1):
    if value > int(arguments["--threshold"]):
        all_funds[bridge.jcli_address(key)] = value
    print(
        f"\r    Processing threshold value {i} of {len(vote_stake.items())}",
        end="",
        file=sys.stderr,
    )
print(f" [{time_delta_to_str(time.time() - timer)}]", file=sys.stderr)

if extra_funds:
    all_funds.update(extra_funds)

timer = time.time()
loops = len(all_funds) // 100 + 1
for i in range(0, loops):
    start = i * 100
    if i == loops:
        end = loops * 100 + len(all_funds) % 100
    else:
        end = (i + 1) * 100
    funds = {"fund": []}
    for key, value in dict(itertools.islice(all_funds.items(), start, end)).items():
        funds["fund"].append({"address": key, "value": value})
    initial_funds.append(funds)
    print(f"\r    Processing initial funds {i + 1} of {loops}", end="", file=sys.stderr)
print(f" [{time_delta_to_str(time.time() - timer)}]", file=sys.stderr)

genesis["initial"] = initial_funds
genesis["blockchain_configuration"]["block0_date"] = timestamp
print(json.dumps(genesis))
