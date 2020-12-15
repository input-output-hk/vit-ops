{ lib, buildLayeredImage, mkEnv, writeShellScript, jormungandr, jq, remarshal
, coreutils, restic, diffutils, procps }:
let
  entrypoint = writeShellScript "jormungandr" ''
    set -exuo pipefail

    nodeConfig="$NOMAD_TASK_DIR/node-config.json"
    runConfig="$NOMAD_TASK_DIR/running.json"
    runYaml="$NOMAD_TASK_DIR/running.yaml"
    name="jormungandr"

    function convert () {
      cp "$nodeConfig" "$runConfig"
      remarshal --if json --of yaml "$runConfig" > "$runYaml"
    }

    if [ "$RESET" = "true" ]; then
      echo "RESET is given, will start from scratch..."
      rm -rf "$STORAGE_DIR"
    elif [ -d "$STORAGE_DIR" ]; then
      echo "$STORAGE_DIR found, not restoring from backup..."
    else
      echo "$STORAGE_DIR not found, restoring backup..."

      restic restore latest \
        --tag "$NAMESPACE" \
        --target / \
      || echo "couldn't restore backup, continue startup procedure..."
    fi

    set +x
    echo "waiting for $REQUIRED_PEER_COUNT peers"
    until [ "$(jq -e -r '.p2p.trusted_peers | length' < "$nodeConfig" || echo 0)" -ge $REQUIRED_PEER_COUNT ]; do
      sleep 1
    done
    set -x

    convert

    (
      while true; do
        while diff -u "$runConfig" "$nodeConfig" > /dev/stderr; do
          sleep 300
        done

        if ! diff -u "$runConfig" "$nodeConfig" > /dev/stderr; then
          convert
          pkill "$name" || true
        fi
      done
    ) &

    starts=0
    while true; do
      starts="$((starts+1))"
      echo "Start Number $starts" > /dev/stderr

      if [ -n "$PRIVATE" ]; then
        echo "Running with node with secrets..."
        jormungandr \
          --storage "$STORAGE_DIR" \
          --config "$NOMAD_TASK_DIR/running.yaml" \
          --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
          --secret $NOMAD_SECRETS_DIR/bft-secret.yaml \
          "$@" || true
      else
        echo "Running with follower node..."
        jormungandr \
          --storage "$STORAGE_DIR" \
          --config "$NOMAD_TASK_DIR/running.yaml" \
          --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
          "$@" || true
      fi

      sleep 10
    done
  '';
in {
  jormungandr = buildLayeredImage {
    name = "docker.vit.iohk.io/jormungandr";
    config = {
      Entrypoint = [ entrypoint ];

      Env = mkEnv {
        PATH = lib.makeBinPath [ jormungandr jq remarshal coreutils restic procps diffutils ];
      };
    };
  };
}
