{ runCommand, writeShellScriptBin, lib, symlinkJoin, debugUtils, fetchurl
, gnutar, jq, remarshal, coreutils, restic, procps, diffutils, strace, ... }:
let
  jormungandr = let
    version = "0.10.0-alpha.2";
    src = fetchurl {
      url =
        "https://github.com/input-output-hk/jormungandr/releases/download/v${version}/jormungandr-${version}-x86_64-unknown-linux-musl-generic.tar.gz";
      sha256 = "sha256-WmlQuY/FvbFR3ba38oh497XmCtftjsrHu9bfKsubqi0=";
    };
  in runCommand "jormungandr" { buildInputs = [ gnutar ]; } ''
    mkdir -p $out/bin
    cd $out/bin
    tar -zxvf ${src}
  '';

  entrypoint = writeShellScriptBin "entrypoint" ''
    set -exuo pipefail

    nodeConfig="$NOMAD_TASK_DIR/node-config.json"
    runConfig="$NOMAD_TASK_DIR/running.json"
    runYaml="$NOMAD_TASK_DIR/running.yaml"
    name="jormungandr"

    chmod u+rwx -R "$NOMAD_TASK_DIR" || true

    function convert () {
      chmod u+rwx -R "$NOMAD_TASK_DIR" || true
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
        --verbose=5 \
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
in symlinkJoin {
  name = "entrypoint";
  paths = debugUtils ++ [
    coreutils
    diffutils
    entrypoint
    jormungandr
    jq
    procps
    remarshal
    restic
  ];
}
