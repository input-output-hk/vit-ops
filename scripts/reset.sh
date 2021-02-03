#!/usr/bin/env bash

set -euo pipefail

[ -n "${1:-}" ] || (echo "Please give the namespace as argument" && exit 1)

NOMAD_NAMESPACE="$1"
export NOMAD_NAMESPACE

# dir="./work/scripts/tmp2"

export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api

NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/admin)"
export NOMAD_TOKEN

CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/admin)";
export CONSUL_HTTP_TOKEN

# cp $dir/{artifacts.json,database.sqlite3,block0.bin} .

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

if ! git diff --exit-code ./artifacts.json; then
  git add ./artifacts.json
  git commit -m "update artifacts for $NOMAD_NAMESPACE"
  git push origin nix-jobs
fi

echo "Resetting $NOMAD_NAMESPACE in 5 seconds..."
sleep 5

# for i in $(seq 0 2); do
#   vault kv put "kv/nomad-cluster/bft/$NOMAD_NAMESPACE/$i" value="@$dir/bft$i.sk"
#   vault kv put "kv/nomad-cluster/committee/$NOMAD_NAMESPACE/$i" value="@$dir/committee$i.sk"
# done

aws s3 cp ./block0.bin "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/block0.bin" --acl public-read
aws s3 cp ./database.sqlite3 "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/database.sqlite3" --acl public-read
vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=true

nomad job stop -purge vit || true
nomad job stop -purge leader-0 || true
nomad job stop -purge leader-1 || true
nomad job stop -purge leader-2 || true
nomad job stop -purge follower-0 || true
nomad job stop -purge servicing-station || true

# nomad job stop -NOMAD_NAMESPACE "$NOMAD_NAMESPACE" backup

sleep 10

levant deploy -vault -var-file "./$NOMAD_NAMESPACE.json" -var-file ./leader-0.json ./jobs/jormungandr.hcl
levant deploy -vault -var-file "./$NOMAD_NAMESPACE.json" -var-file ./leader-1.json ./jobs/jormungandr.hcl
levant deploy -vault -var-file "./$NOMAD_NAMESPACE.json" -var-file ./leader-2.json ./jobs/jormungandr.hcl
levant deploy -vault -var-file "./$NOMAD_NAMESPACE.json" -var-file ./follower-0.json ./jobs/jormungandr.hcl
levant deploy -vault -var-file "./$NOMAD_NAMESPACE.json" ./jobs/servicing-station.hcl

# nix run ".#nomadJobs.$NOMAD_NAMESPACE.run"
# nomad job run -var "NOMAD_NAMESPACE=$NOMAD_NAMESPACE" -var rev=a1b113f60d72bd273946e2caef6a0706874c04cc ./jobs/servicing-station.hcl
# nix run ".#nomadJobs.$NOMAD_NAMESPACE-backup.run"

echo "Please verify that everything started correctly, then hit return"
read -r
vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=false
