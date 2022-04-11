{ inputs, self }:
final: prev:
let inherit (final) lib;
in {
  inherit (inputs.jormungandr.packages."${final.system}") jormungandr;

  nodePkgs = inputs.cardano-node.legacyPackages."${final.system}";
  node-scripts = final.nodePkgs.scripts;

  db-sync-testnet-scripts =
    inputs.cardano-db-sync-testnet.legacyPackages."${final.system}".scripts;

  db-sync-mainnet-scripts =
    inputs.cardano-db-sync-mainnet.legacyPackages."${final.system}".scripts;

  postgres-entrypoint = final.callPackage ./pkgs/postgres-entrypoint.nix { };

  inherit (inputs.vit-servicing-station.packages."${final.system}")
    vit-servicing-station-server vit-servicing-station-cli;

  jormungandr-entrypoint = final.callPackage ./pkgs/jormungandr.nix { };

  print-env = final.callPackage ./pkgs/print-env.nix { };

  zipkin-server = final.callPackage ./pkgs/zipkin-server.nix { };

  restic-backup = final.callPackage ./pkgs/restic-backup { };

  nomad-driver-nspawn = final.callPackage ./pkgs/nomad-driver-nspawn.nix { };

  checkFmt = final.writeShellScriptBin "check_fmt.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ git nixfmt gnugrep ])}"
    . ${./pkgs/check_fmt.sh}
  '';

  checkCue = final.writeShellScriptBin "check_cue.sh" ''
    export PATH="$PATH:${lib.makeBinPath (with final; [ cue ])}"
    cue vet -c
  '';

  debugUtils = with final; [
    bashInteractive
    coreutils
    curl
    fd
    findutils
    gnugrep
    gnused
    htop
    lsof
    netcat
    procps
    ripgrep
    sqlite-interactive
    strace
    tcpdump
    tmux
    tree
    utillinux
    vim
  ];

  devShell = let
    clusterName = builtins.elemAt (builtins.attrNames final.clusters) 0;
    inherit (final.clusters."${clusterName}".proto.config) cluster;
  in prev.mkShell {
    # for bitte-cli
    LOG_LEVEL = "debug";

    DOMAIN = cluster.domain;
    NOMAD_NAMESPACE = "catalyst-dryrun";
    BITTE_CLUSTER = cluster.name;
    AWS_PROFILE = "vit";
    AWS_DEFAULT_REGION = cluster.region;
    TERRAFORM_ORGANIZATION = cluster.terraformOrganization;

    VAULT_ADDR = "https://vault.${cluster.domain}";
    NOMAD_ADDR = "https://nomad.${cluster.domain}";
    CONSUL_HTTP_ADDR = "https://consul.${cluster.domain}";
    NIX_USER_CONF_FILES = ./nix.conf;

    buildInputs = with final; [
      awscli
      bitte
      cfssl
      consul
      consul-template
      direnv
      jq
      nixfmt
      nomad
      openssl
      pkgconfig
      restic
      sops
      terraform-with-plugins
      vault-bin
      ruby
      cue
    ];
  };

  # Used for caching
  devShellPath = prev.symlinkJoin {
    paths = final.devShell.buildInputs ++ [ final.nixFlakes ];
    name = "devShell";
  };

  inherit (inputs.nixpkgs-unstable.legacyPackages."${final.system}") traefik;
}
