#!/usr/bin/env bash

set -exuo pipefail

rm -f ./*.{sk,pk}

export TZ="UTC"

format="+%Y-%m-%dT%H:%M:%SZ"
now="$(date --date '15 minutes' "$format")"
fund_start_time="$(date --date "$now" "$format")"
fund_end_time="$(date --date "$now 4 days" "$format")"
voting_power_info="$(date --date "$now -1 day" "$format")"
rewards_info="$(date --date "$now -1 day" "$format")"
next_fund_start_time="$(date --date "$now 1 month" "$format")"
voteplan="$(< voteplan-template.json)"
block0_time="$(date "$format")"
block0_date="$(date --date "$block0_time" +%s)"

keysArgs=()
voteKeys=()
comKeys=()

textql -output-file sql_funds_out.csv -output-header -header -sql "
  update sql_funds set fund_start_time = '$fund_start_time';
  update sql_funds set fund_end_time = '$fund_end_time';
  update sql_funds set voting_power_info = '$voting_power_info';
  update sql_funds set rewards_info = '$rewards_info';
  update sql_funds set next_fund_start_time = '$next_fund_start_time';
  select * from sql_funds
" sql_funds.csv
sed -i -r '/^\s*$/d' sql_funds_out.csv

genesis="$(
  jq --argjson d "$block0_date" \
    '.blockchain_configuration.block0_date = $d' \
    < genesis-template.json
)"

crs=$(jcli votes crs generate)

for i in $(seq 0 2); do
  jcli key generate --type=ed25519 > "committee$i.sk"
  jcli key to-public < "committee$i.sk" > "./committee$i.pk"

  commAccount="$(jcli address account "$(< "./committee$i.pk")")"
  genesis="$(echo "$genesis" | jq --arg k "$commAccount" '.initial[0].fund += [{"address":$k,"value":10000000001}]')"

  jcli key generate --type=ed25519 > "bft$i.sk"
  jcli key to-public < "bft$i.sk" > "./bft$i.pk"

  bftAccount="$(jcli address account "$(< "./bft$i.pk")")"
  genesis="$(echo "$genesis" | jq --arg k "$bftAccount" '.initial[0].fund += [{"address":$k,"value":10000000002}]')"
  genesis="$(echo "$genesis" | jq --arg k "$(< "bft$i.pk")" '.blockchain_configuration.consensus_leader_ids += [ $k ]')"

  bytes="$(jcli key to-bytes < "committee$i.pk")"
  genesis="$(echo "$genesis" | jq --arg k "$bytes" '.blockchain_configuration.committees += [ $k ]')"

  comKeys+=("-committee-auth-public-key" "$(< "committee$i.sk")")
  jcli votes committee communication-key generate > "comm$i.sk"
  jcli votes committee communication-key to-public --input "comm$i.sk" > "comm$i.pk"
  keysArgs+=("--keys" "$(< "comm$i.pk")")
done

for i in $(seq 0 2); do
  jcli votes committee member-key generate --threshold 3 --crs "$crs" --index "$i" "${keysArgs[@]}" > "./member$i.sk"
  jcli votes committee member-key to-public --input "./member$i.sk" > "./member$i.pk"
  voteKeys+=("--keys" "$(< "./member$i.pk")")
  voteplan="$(echo "$voteplan" | jq --arg k "$(< "member$i.pk")" '.committee_member_public_keys += [ $k ]')"
done

# set +x
# for addr in $(echo "$qrCodes" | jq '. | keys | .[]' -r); do
#   genesis="$(echo "$genesis" | jq --arg k "$addr" '.initial[0].fund += [{"address":$k,"value":10000000002}]')"
# done
# set -x

echo "$genesis" > genesis.json
jcli genesis encode --input genesis.json --output block0.bin

jcli votes encrypting-key "${voteKeys[@]}" > "./vote.pk"

# voteplans
# chain_vote_start_time = fund_start_time
# chain_vote_end_time = fund_end_time
# chain_committee_end_time = fund_end_time + 1 day

# funds
# rewards_info
# fund_start_time
# fund_end_time
# next_fund_start_time

echo "$voteplan" > voteplan.json
jcli certificate new vote-plan voteplan.json --output voteplan.certificate
rm -rf jnode_VIT_*
vitconfig \
  -fund sql_funds_out.csv \
  -proposals fund2-proposals.csv \
  -vote-start "$fund_start_time" \
  -vote-end "$fund_end_time" \
  -genesis-time "$block0_time" \
  "${comKeys[@]}" \
  || true # this command has to fail for some reason


cp jnode_VIT_*/vote_plans/public_voteplan_*.json catalyst_dryrun.json

rm -f database.sqlite3
vit-servicing-station-cli db init --db-url ./database.sqlite3
vit-servicing-station-cli csv-data load \
  --db-url database.sqlite3 \
  --funds sql_funds_out.csv \
  --proposals jnode_VIT_*/vit_station/sql_proposals.csv \
  --voteplans jnode_VIT_*/vit_station/sql_voteplans.csv

artifacts="$(cat artifacts.json || echo '{}')"

artifacts="$(
  echo "$artifacts" \
    | jq --arg h "sha256:$(
        sha256sum block0.bin | awk '{ print $1 }'
      )" '."catalyst-dryrun".block0.checksum = $h'
)"

artifacts="$(
  echo "$artifacts" \
    | jq --arg h "sha256:$(
        sha256sum database.sqlite3 | awk '{ print $1 }'
      )" '."catalyst-dryrun".database.checksum = $h'
)"

echo "$artifacts"  > artifacts.json
