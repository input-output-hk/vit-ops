#!/usr/bin/env bash

set -exuo pipefail

export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api

VOTE_PLAN_ID="$(jcli rest v0 vote active plans get --output-format json|jq -r '.[0].id')"
COMMITTEE_KEY=committee
COMMITTEE_ADDR=$(jcli address account "$(jcli key to-public < "$COMMITTEE_KEY")")
COMMITTEE_ADDR_COUNTER=$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq -r .counter)

jcli certificate new vote-tally public --vote-plan-id "$VOTE_PLAN_ID" --output vote_tally.certificate
jcli transaction new --staging vote_tally.staging
jcli transaction add-account "$COMMITTEE_ADDR" 0 --staging vote_tally.staging
jcli transaction add-certificate "$(< vote_tally.certificate)" --staging vote_tally.staging
jcli transaction finalize --staging vote_tally.staging
jcli transaction data-for-witness --staging vote_tally.staging > vote_tally.witness_data
jcli transaction make-witness --genesis-block-hash "$(jcli genesis hash < block0.bin)" --type account --account-spending-counter "$COMMITTEE_ADDR_COUNTER" "$(< vote_tally.witness_data)" vote_tally.witness "$COMMITTEE_KEY"
jcli transaction add-witness --staging vote_tally.staging vote_tally.witness
jcli transaction seal --staging vote_tally.staging
jcli transaction auth --staging vote_tally.staging --key "$COMMITTEE_KEY"
jcli transaction to-message --staging vote_tally.staging > vote_tally.fragment
jcli rest v0 message post --file vote_tally.fragment
sleep 10
jcli rest v0 vote active plans get

vitresult \
  -node-addr https://dryrun-servicing-station.vit.iohk.io \
  -service-addr https://dryrun-servicing-station.vit.iohk.io
