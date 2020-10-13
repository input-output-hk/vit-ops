{ system, self }:
let
  extraJobArgs = {
    block0 = "${self.inputs.vit-servicing-station}/docker/master/block0.bin";
    db = "${self.inputs.vit-servicing-station}/docker/master/database.db";
  };
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

  dockerImages = {
    vit = let
      pkgs = self.legacyPackages.${system};
      inherit (self.inputs.nixpkgs) lib;

      source = pkgs.fetchurl {
        url =
          "https://github.com/input-output-hk/jormungandr/releases/download/nightly.20200922/jormungandr-0.10.0-nightly.20200922-x86_64-unknown-linux-musl-generic.tar.gz";
        sha256 = "sha256-deA5WjnwtDxTbxWqP/KMro0Ps4zTcnfcpeoawFpstgY=";
      };

      jormungandr = pkgs.runCommand "jormungandr" { } ''
        set -exuo pipefail
        tar xvf ${source}
        mkdir -p $out/{bin,share}
        cp j* $out/bin
        cp ${./jobs/block0.bin} $out/share/block0.bin
      '';

      push = pkgs.writeShellScriptBin "upload" ''
        set -exuo pipefail
        docker load -i ${image}
        docker push docker.vit.iohk.io/vit:latest
      '';

      image =
        (self.inputs.nixpkgs.legacyPackages.${system}).dockerTools.buildLayeredImage {
          name = "docker.vit.iohk.io/vit";
          tag = "latest";

          contents = [ jormungandr pkgs.busybox ];

          config = {
            Entrypoint = [ "${jormungandr}/bin/jormungandr" ];

            Env = lib.mapAttrsToList (key: value: "${key}=${value}") {
              PATH = lib.makeBinPath [ jormungandr pkgs.busybox ];
            };
          };
        };
    in { inherit push image; };
  };

  jormungandr-monitor = final.callPackage
    (self.inputs.jormungandr-nix + "/nixos/jormungandr-monitor") {
      jormungandr-cli = "."; # pick up from "./bin/jcli" local path
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
      final.bitte-tokens
      final.jq
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs ++ [ final.nixFlakes ];
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
    consul consul-template bitte-tokens systemd-runner;

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
