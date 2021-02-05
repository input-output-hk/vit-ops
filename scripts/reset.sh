#!/usr/bin/env bash

set -euo pipefail

[ -n "${1:-}" ] || (echo "Please give the namespace as argument" && exit 1)

NOMAD_NAMESPACE="$1"
export NOMAD_NAMESPACE

export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api

NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/admin)"
export NOMAD_TOKEN

CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/admin)";
export CONSUL_HTTP_TOKEN

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

aws s3 cp ./block0.bin "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/block0.bin" --acl public-read
aws s3 cp ./database.sqlite3 "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/database.sqlite3" --acl public-read
vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=true

./deploy.rb stop

sleep 10

./deploy.rb run

echo "Please verify that everything started correctly, then hit return"
read -r
vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=false
