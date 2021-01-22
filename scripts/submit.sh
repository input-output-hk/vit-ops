#!/usr/bin/env bash

set -exuo pipefail

VOTE_PLAN="work/scripts/tmp2/catalyst_dryrun.json"
export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api
COMMITTEE_KEY=work/scripts/tmp2/committee0.sk
COMMITTEE_ADDR="$(jcli address account "$(jcli key to-public < "$COMMITTEE_KEY")")"
COMMITTEE_ADDR_COUNTER="$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq .counter)"
jcli certificate new vote-plan "$VOTE_PLAN" --output vote_plan.certificate
jcli transaction new --staging vote_plan.staging
jcli transaction add-account "$COMMITTEE_ADDR" 0 --staging vote_plan.staging
jcli transaction add-certificate "$(< vote_plan.certificate)" --staging vote_plan.staging
jcli transaction finalize --staging vote_plan.staging
jcli transaction data-for-witness --staging vote_plan.staging > vote_plan.witness_data
jcli transaction make-witness --genesis-block-hash "$(jcli genesis hash < block0.bin)" --type account --account-spending-counter "$COMMITTEE_ADDR_COUNTER" "$(< vote_plan.witness_data)" vote_plan.witness "$COMMITTEE_KEY"
jcli transaction add-witness --staging vote_plan.staging vote_plan.witness
jcli transaction seal --staging vote_plan.staging
jcli transaction auth --staging vote_plan.staging --key "$COMMITTEE_KEY"
jcli transaction to-message --staging vote_plan.staging > vote_plan.fragment
jcli rest v0 message post --file vote_plan.fragment
jcli rest v0 vote active plans get
