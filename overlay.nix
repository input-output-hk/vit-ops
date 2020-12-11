{ system, self }:
let extraJobArgs = { };
in final: prev:
let lib = final.lib;
in {
  vit-servicing-station = final.runCommand "vit-servicing-station-static" {
    src = final.fetchurl {
      url =
        "https://github.com/mzabaluev/vit-servicing-station/releases/download/v0.1.0-ci-test.1/vit-servicing-station-0.1.0-ci-test.1-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "sha256-esVtO4GzQob7Xev1RzaBq7SU1u4noCml2lAfghRJuHg=";
    };
  } ''
    mkdir -pv $out/bin
    tar -xvf $src -C $out/bin/
  '';

  nomadJobs = let
    jobsDir = ./jobs;
    contents = builtins.readDir jobsDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackage (jobsDir + "/${fileName}") extraJobArgs);
  in lib.foldl' lib.recursiveUpdate { } imported;

  dockerImages = let
    imageDir = ./docker;
    contents = builtins.readDir imageDir;
    toImport = name: type: type == "regular" && lib.hasSuffix ".nix" name;
    fileNames = builtins.attrNames (lib.filterAttrs toImport contents);
    imported = lib.forEach fileNames
      (fileName: final.callPackages (imageDir + "/${fileName}") { });
    merged = lib.foldl' lib.recursiveUpdate { } imported;
  in lib.flip lib.mapAttrs merged (key: image:
    let id = "${image.imageName}:${image.imageTag}";
    in {
      inherit id image;

      # Turning this attribute set into a string will return the outPath instead.
      outPath = id;

      push = let
        parts = builtins.split "/" image.imageName;
        registry = builtins.elemAt parts 0;
        repo = builtins.elemAt parts 2;
      in final.writeShellScriptBin "push" ''
        set -euo pipefail

        export dockerLoginDone="''${dockerLoginDone:-}"
        export dockerPassword="''${dockerPassword:-}"

        if [ -z "$dockerPassword" ]; then
          dockerPassword="$(vault kv get -field value kv/nomad-cluster/docker-developer-password)"
        fi

        if [ -z "$dockerLoginDone" ]; then
          echo "$dockerPassword" | docker login docker.mantis.ws -u developer --password-stdin
          dockerLoginDone=1
        fi

        echo -n "Pushing ${image.imageName}:${image.imageTag} ... "

        if curl -s "https://developer:$dockerPassword@${registry}/v2/${repo}/tags/list" | grep "${image.imageTag}" &> /dev/null; then
          echo "Image already exists in registry"
        else
          docker load -i ${image}
          docker push ${image.imageName}:${image.imageTag}
        fi
      '';

      load = builtins.trace key (final.writeShellScriptBin "load" ''
        set -euo pipefail
        echo "Loading ${image} (${image.imageName}:${image.imageTag}) ..."
        docker load -i ${image}
      '');
    });
  push-docker-images = final.writeShellScriptBin "push-docker-images" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n"
    (lib.mapAttrsToList (key: value: "${value.push}/bin/push")
      final.dockerImages)}
  '';

  load-docker-images = final.writeShellScriptBin "load-docker-images" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n"
    (lib.mapAttrsToList (key: value: "${value.load}/bin/load")
      final.dockerImages)}
  '';

  inherit ((self.inputs.nixpkgs.legacyPackages.${system}).dockerTools)
    buildLayeredImage;

  mkEnv = lib.mapAttrsToList (key: value: "${key}=${value}");

  jormungandr = let
    version = "0.10.0-alpha.2";
    src = final.fetchurl {
      url =
        "https://github.com/input-output-hk/jormungandr/releases/download/v${version}/jormungandr-${version}-x86_64-unknown-linux-musl-generic.tar.gz";
      sha256 = "sha256-WmlQuY/FvbFR3ba38oh497XmCtftjsrHu9bfKsubqi0=";
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

  restic-backup = final.callPackage ./pkgs/restic-backup { };

  debugUtils = with final; [
    bashInteractive
    coreutils
    curl
    dnsutils
    fd
    gawk
    gnugrep
    iproute
    jq
    lsof
    netcat
    nettools
    procps
    tree
  ];

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
      final.awscli
      final.bitte
      final.cfssl
      final.consul
      final.consul-template
      final.direnv
      final.jormungandr
      final.jq
      final.nixFlakes
      final.nixfmt
      final.nomad
      final.openssl
      final.restic
      final.terraform-with-plugins
      final.vault-bin
      final.crystal
      final.pkgconfig
      final.openssl
      prev.sops
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
