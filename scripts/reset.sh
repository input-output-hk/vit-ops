#!/usr/bin/env bash

set -euo pipefail

NOMAD_NAMESPACE="${NOMAD_NAMESPACE:-}"

if [ -z "$NOMAD_NAMESPACE" ]; then
  echo "Please set the NOMAD_NAMESPACE environment variable first"
  exit 1
fi

export NOMAD_NAMESPACE
echo "[x] NOMAD_NAMESPACE"

VAULT_TOKEN="${VAULT_TOKEN:-}"
if vault token lookup &> /dev/null; then
  echo "Vault token found and valid"
else
  echo "Vault token missing or invalid, please login"
  VAULT_TOKEN="$(vault login -method github -path github-employees -token-only)"
fi

export VAULT_TOKEN
echo "[x] VAULT_TOKEN"

NOMAD_TOKEN="${NOMAD_TOKEN:-}"

if [ -z "$NOMAD_TOKEN" ]; then
  echo "Nomad token missing, fetching new one"
  NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"
else
  if nomad acl token self | grep -v  'Secret ID' &> /dev/null; then
    echo "Nomad token found and valid"
  else
    echo "Nomad token found but invalid, fetching new one"
    NOMAD_TOKEN="$(vault read -field secret_id nomad/creds/developer)"
  fi
fi

export NOMAD_TOKEN
echo "[x] NOMAD_TOKEN"

CONSUL_HTTP_TOKEN="${CONSUL_HTTP_TOKEN:-}"

if [ -z "$CONSUL_HTTP_TOKEN" ]; then
  echo "Consul token missing, fetching new one"
  CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/developer)"
else
  if consul acl token read -self -format json | jq -e '.Policies | map(.Name) | inside(["admin", "github-employees"])' &>/dev/null; then
    echo "Consul token found and valid"
  else
    echo "Consul token found but invalid, fetching new one"
    CONSUL_HTTP_TOKEN="$(vault read -field token consul/creds/developer)"
  fi
fi

export CONSUL_HTTP_TOKEN
echo "[x] CONSUL_HTTP_TOKEN"

aws s3 ls &> /dev/null \
|| (
  echo "AWS credentials are insufficient, setting them in $AWS_PROFILE"

  if grep "\[$AWS_PROFILE\]" ~/.aws/credentials; then
    echo "AWS profile exists, updating credentials"
  else
    echo "AWS profile $AWS_PROFILE will be created"
    mkdir -p ~/.aws
    printf "\\n[%s]" "$AWS_PROFILE" >> ~/.aws/credentials
  fi

  creds="$(vault read -format json aws/creds/developer)"
  aws configure set --profile "$AWS_PROFILE" aws_access_key_id \
    "$( echo "$creds" | jq -r -e .data.access_key )"
  aws configure set --profile "$AWS_PROFILE" aws_secret_access_key \
    "$(echo "$creds" | jq -r -e .data.secret_key)"
  echo "AWS credentials are set, waiting for them to be visible..."
  until aws s3 ls &> /dev/null; do
    sleep 5
  done
)

echo "[x] AWS credentials"

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
  echo "Found difference in artifacts.json, pushing for consistency"
  git add ./artifacts.json
  git commit -m "update artifacts for $NOMAD_NAMESPACE"
  git push origin nix-jobs
fi

echo "[x] Artifacts"

echo "Resetting $NOMAD_NAMESPACE in 5 seconds..."
sleep 5

aws s3 cp ./block0.bin "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/block0.bin" --acl public-read
aws s3 cp ./database.sqlite3 "s3://iohk-vit-artifacts/$NOMAD_NAMESPACE/database.sqlite3" --acl public-read
vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=true

./deploy.rb stop

sleep 10

./deploy.rb run

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
echo "Please verify that everything started correctly, then confirm."
echo "If you accidentially confirm too early, you may have to reset again."
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

CONT=""
until [ -n "$CONT" ]; do
  read -r -p "Confirm by writing confirm (confirm)? " CONT
  if [ "$CONT" = "confirm" ]; then
    vault kv put "kv/nomad-cluster/$NOMAD_NAMESPACE/reset" value=false
  fi
done
