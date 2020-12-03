{ lib, buildLayeredImage, mkEnv, writeShellScript, jormungandr, jq, remarshal
, coreutils, restic }:
let
  entrypoint = writeShellScript "jormungandr" ''
    set -exuo pipefail

    echo "restoring backup..."

    rm -rf "$STORAGE_DIR"

    restic restore latest \
      --tag $NAMESPACE \
      --target / \
    || echo "couldn't restore backup, continue startup procedure..."

    ls -laR $STORAGE_DIR

    set +x
    echo "waiting for $REQUIRED_PEER_COUNT peers"
    until [ "$(jq -e -r '.p2p.trusted_peers | length' < "$NOMAD_TASK_DIR/node-config.json" || echo 0)" -ge $REQUIRED_PEER_COUNT ]; do
      sleep 0.1
    done
    set -x

    remarshal --if json --of yaml "$NOMAD_TASK_DIR/node-config.json" > "$NOMAD_TASK_DIR/running.yaml"

    if [ -n "$PRIVATE" ]; then
      echo "Running with node with secrets..."
      exec jormungandr \
        --storage "$STORAGE_DIR" \
        --config "$NOMAD_TASK_DIR/running.yaml" \
        --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
        --secret $NOMAD_SECRETS_DIR/bft-secret.yaml
    else
      echo "Running with follower node..."
      exec jormungandr \
        --storage "$STORAGE_DIR" \
        --config "$NOMAD_TASK_DIR/running.yaml" \
        --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin
    fi
  '';
in {
  jormungandr = buildLayeredImage {
    name = "docker.vit.iohk.io/jormungandr";
    config = {
      Entrypoint = [ entrypoint ];

      Env = mkEnv {
        PATH = lib.makeBinPath [ jormungandr jq remarshal coreutils restic ];
      };
    };
  };
}
