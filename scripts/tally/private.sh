#!/usr/bin/env bash

set -exuo pipefail

export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api

VOTE_PLAN_ID="$(jcli rest v0 vote active plans get --output-format json|jq -r '.[0].id')"

curl $JORMUNGANDR_RESTAPI_URL/v0/block0 > block0.bin

BLOCK0_HASH=$(jcli genesis hash --input block0.bin)
COMMITTEE_KEY=committee_1
MEMBER_SECRET_KEY=member_secret_key.sk

COMMITTEE_ADDR=$(jcli address account "$(jcli key to-public < "$COMMITTEE_KEY")")
COMMITTEE_ADDR_COUNTER=$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq -r .counter)

jcli "certificate" "new" "encrypted-vote-tally" "--vote-plan-id" "$VOTE_PLAN_ID" "--output" "encrypted-vote-tally.certificate"
jcli "transaction" "new" "--staging" "transaction.tx"
jcli "transaction" "add-account" "$COMMITTEE_ADDR" "0" "--staging" "transaction.tx"
jcli "transaction" "add-certificate" "$(< encrypted-vote-tally.certificate)" "--staging" "transaction.tx"
jcli "transaction" "finalize" "--staging" "transaction.tx"
jcli "transaction" "data-for-witness" "--staging" "transaction.tx" > encrypted-vote-tally.witness_data

jcli "transaction" "make-witness" "--genesis-block-hash" "$BLOCK0_HASH" "--type" "account" "--account-spending-counter" "$COMMITTEE_ADDR_COUNTER" "$(< encrypted-vote-tally.witness_data)" vote_tally.witness "$COMMITTEE_KEY"
jcli "transaction" "add-witness" "vote_tally.witness" "--staging" "transaction.tx"
jcli "transaction" "seal" "--staging" "transaction.tx"
jcli "transaction" "auth" "--staging" "transaction.tx" "--key" "$COMMITTEE_KEY"
jcli "transaction" "to-message" "--staging" "transaction.tx" > encrypted-vote-tally.fragment
jcli rest v0 message post --file encrypted-vote-tally.fragment

sleep 20

jcli rest v0 vote active plans get --output-format json > active_plans.json
COMMITTEE_ADDR_COUNTER=$(jcli rest v0 account get "$COMMITTEE_ADDR" --output-format json|jq -r .counter)


jcli "votes" "tally" "decryption-shares" "--vote-plan" "active_plans.json" "--vote-plan-id" "$VOTE_PLAN_ID" "--key"  "$MEMBER_SECRET_KEY" > decryption_share.json

jcli "votes" "tally" "merge-shares" "decryption_share.json" > shares.json

jcli "votes" "tally" "decrypt-results" "--vote-plan" "active_plans.json" "--vote-plan-id" "$VOTE_PLAN_ID" "--shares" "shares.json" "--threshold" "1" "--output-format" "json" > result.json

jcli "certificate" "new" "vote-tally" "private" "--shares" "shares.json" "--vote-plan" "result.json" "--vote-plan-id" "$VOTE_PLAN_ID" --output "vote-tally.certificate"
jcli "transaction" "new" "--staging" "transaction.tx"
jcli "transaction" "add-account" "$COMMITTEE_ADDR" "0" "--staging" "transaction.tx"
jcli "transaction" "add-certificate" "$(< vote-tally.certificate)" "--staging" "transaction.tx"
jcli "transaction" "finalize" "--staging" "transaction.tx"
jcli "transaction" "data-for-witness" "--staging" "transaction.tx" > vote-tally.witness_data

jcli "transaction" "make-witness" "--genesis-block-hash" "$BLOCK0_HASH" "--type" "account" "--account-spending-counter" "$COMMITTEE_ADDR_COUNTER" "$(< vote-tally.witness_data)" vote_tally.witness "$COMMITTEE_KEY"
jcli "transaction" "add-witness" "vote_tally.witness" "--staging" "transaction.tx"
jcli "transaction" "seal" "--staging" "transaction.tx"
jcli "transaction" "auth" "--staging" "transaction.tx" "--key" "$COMMITTEE_KEY"
jcli "transaction" "to-message" "--staging" "transaction.tx" > vote-tally.fragment
jcli rest v0 message post --file vote-tally.fragment
