{ system, self }:
let extraJobArgs = { };
in final: prev:
let lib = final.lib;
in {
  inherit (self.inputs.rust-libs.legacyPackages.${system})
    vit-servicing-station;

  nomadJobs = let
    jobsDir = ./jobs;
    contents = builtins.readDir jobsDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackage (jobsDir + "/${fileName}") extraJobArgs);
  in lib.foldl' lib.recursiveUpdate { } imported;

  jormungandr = let
    version = "0.10.0-alpha.1";
    src = final.fetchurl {
      url =
        "https://github.com/input-output-hk/jormungandr/releases/download/v${version}/jormungandr-${version}-x86_64-unknown-linux-musl-generic.tar.gz";
      sha256 = "sha256-DMIU+YLCMXY8PB4lHVw9j87ffNrNM1k0aeq/9OaK/88=";
    };
  in final.runCommand "jormungandr" { buildInputs = [ final.gnutar ]; } ''
    mkdir -p $out/bin
    cd $out/bin
    tar -zxvf ${src}
  '';

  jormungandr-monitor = final.callPackage
    (self.inputs.jormungandr-nix + "/nixos/jormungandr-monitor") {
      jormungandr-cli = final.jormungandr;
    };

  dockerImages = let
    inherit ((self.inputs.nixpkgs.legacyPackages.${system}).dockerTools)
      buildLayeredImage;
    pkgs = self.legacyPackages.${system};
    inherit (self.inputs.nixpkgs) lib;

    mkPush = image:
      pkgs.writeShellScriptBin "upload" ''
        set -exuo pipefail
        docker load -i ${image}
        docker push ${image.imageName}:${image.imageTag}
      '';
  in {
    jormungandr = let
      name = "docker.vit.iohk.io/jormungandr";
      push = mkPush image;
      image = buildLayeredImage {
        inherit name;
        config = {
          Entrypoint = [
            (final.writeShellScript "jormungandr" ''
              set -exuo pipefail

              set +x
              echo "waiting for $REQUIRED_PEER_COUNT peers"
              until [ "$(jq -r '.p2p.trusted_peers | length' < "$NOMAD_TASK_DIR/node-config.json")" -ge $REQUIRED_PEER_COUNT ]; do
                sleep 0.1
              done
              set -x

              remarshal --if json --of yaml "$NOMAD_TASK_DIR/node-config.json" > "$NOMAD_TASK_DIR/running.yaml"

              secret=""
              if [ -n $PRIVATE ]; then
                secret="--secret $NOMAD_SECRETS_DIR/bft-secret.yaml"
              fi

              exec ${final.jormungandr}/bin/jormungandr \
                --storage "$NOMAD_TASK_DIR" \
                --config "$NOMAD_TASK_DIR/running.yaml" \
                --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
                $secret
            '')
          ];

          Env = lib.mapAttrsToList (key: value: "${key}=${value}") {
            PATH = lib.makeBinPath [
              final.jormungandr
              pkgs.jq
              pkgs.remarshal
              pkgs.coreutils
            ];
          };
        };
      };
    in {
      inherit image push;
      id = "${image.imageName}:${image.imageTag}";
    };

    monitor = let
      name = "docker.vit.iohk.io/monitor";
      push = mkPush image;
      image = buildLayeredImage {
        inherit name;
        config = {
          Entrypoint = [ final.jormungandr-monitor ];

          Env = lib.mapAttrsToList (key: value: "${key}=${value}") {
            SSL_CERT_FILE = "${final.cacert}/etc/ssl/certs/ca-bundle.crt";
          };
        };
      };
    in {
      inherit image push;
      id = "${image.imageName}:${image.imageTag}";
    };

    env = let
      name = "docker.vit.iohk.io/env";
      push = mkPush image;
      image = buildLayeredImage {
        inherit name;
        config.Entrypoint = [ "${final.coreutils}/bin/env" ];
      };
    in {
      inherit image push;
      id = "${image.imageName}:${image.imageTag}";
    };

    telegraf = let
      name = "docker.vit.iohk.io/telegraf";
      push = mkPush image;
      image = buildLayeredImage {
        inherit name;
        contents = [ final.telegraf ];
        config.Entrypoint = [ "${final.telegraf}/bin/telegraf" ];
      };
    in {
      inherit image push;
      id = "${image.imageName}:${image.imageTag}";
    };

    vit-servicing-station = let
      name = "docker.vit.iohk.io/vit-servicing-station";
      push = mkPush image;
      image = buildLayeredImage {
        inherit name;
        contents = [ final.vit-servicing-station ];
        config.Entrypoint =
          [ "${final.vit-servicing-station}/bin/vit-servicing-station-server" ];
      };
    in {
      inherit image push;
      id = "${image.imageName}:${image.imageTag}";
    };
  };

  devShell = let
    cluster = "vit-testnet";
    domain = final.clusters.${cluster}.proto.config.cluster.domain;
  in prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    BITTE_CLUSTER = cluster;
    AWS_PROFILE = "vit";
    AWS_DEFAULT_REGION = final.clusters.${cluster}.proto.config.cluster.region;

    VAULT_ADDR = "https://vault.${domain}";
    NOMAD_ADDR = "https://nomad.${domain}";
    CONSUL_HTTP_ADDR = "https://consul.${domain}";
    NIX_USER_CONF_FILES = ./nix.conf;

    buildInputs = [
      final.bitte
      final.terraform-with-plugins
      prev.sops
      final.vault-bin
      final.openssl
      final.cfssl
      final.nixfmt
      final.awscli
      final.nomad
      final.consul
      final.consul-template
      final.python38Packages.pyhcl
      final.direnv
      final.nixFlakes
      final.jq
      final.jormungandr
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs
      ++ [ final.nixFlakes final.vit-servicing-station ];
    name = "devShell";
  };

  nixosConfigurations =
    self.inputs.bitte.legacyPackages.${system}.mkNixosConfigurations
    final.clusters;

  clusters = self.inputs.bitte.legacyPackages.${system}.mkClusters {
    root = ./clusters;
    inherit self system;
  };

  inherit (self.inputs.bitte.legacyPackages.${system})
    vault-bin mkNomadJob terraform-with-plugins systemdSandbox nixFlakes nomad
    consul consul-template systemd-runner seaweedfs grpcdump;

  # inject vault-bin into bitte wrapper
  bitte = let
    bitte-nixpkgs = import self.inputs.nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          vault-bin = self.inputs.bitte.legacyPackages.${system}.vault-bin;
        })
        self.inputs.bitte-cli.overlay.${system}
      ];
    };
  in bitte-nixpkgs.bitte;
}
