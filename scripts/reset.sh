#!/usr/bin/env bash

set -euo pipefail

[ -n "${1:-}" ] || (echo "Please give the namespace as argument" && exit 1)

namespace="$1"

dir="./work/scripts/tmp2"

export NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/admin)"
export CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/admin)";
export JORMUNGANDR_RESTAPI_URL=https://dryrun-servicing-station.vit.iohk.io/api
export VOTE_PLAN="$dir/catalyst_dryrun.json"

cp $dir/{artifacts.json,database.sqlite3,block0.bin} .

if ! git diff --exit-code ./artifacts.json; then
  git add ./artifacts.json
  git commit -m "update artifacts for $namespace"
  git push origin nix-jobs
fi

echo "Resetting $namespace in 5 seconds..."
sleep 5

for i in $(seq 0 2); do
  vault kv put "kv/nomad-cluster/bft/$namespace/$i" value="@$dir/bft$i.sk"
  vault kv put "kv/nomad-cluster/committee/$namespace/$i" value="@$dir/committee$i.sk"
done

aws s3 cp ./block0.bin "s3://iohk-vit-artifacts/$namespace/block0.bin" --acl public-read
aws s3 cp ./database.sqlite3 "s3://iohk-vit-artifacts/$namespace/database.sqlite3" --acl public-read
vault kv put "kv/nomad-cluster/$namespace/reset" value=true
nomad job stop -namespace "$namespace" -purge vit || true
nomad job stop -namespace "$namespace" -purge servicing-station || true
# nomad job stop -namespace "$namespace" backup
sleep 5
nix run ".#nomadJobs.$namespace.run"
nomad job run -var "namespace=$namespace" -var rev=a1b113f60d72bd273946e2caef6a0706874c04cc ./jobs/servicing-station.hcl
# nix run ".#nomadJobs.$namespace-backup.run"
echo "Please verify that everything started correctly, then hit return"
read -r
vault kv put "kv/nomad-cluster/$namespace/reset" value=false
