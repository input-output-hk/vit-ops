{ inputs, self }:
final: prev:
let lib = final.lib;
in {
  rev =
    self.rev or (builtins.throw "please commit and push before invoking jobs");

  artifacts = builtins.fromJSON (builtins.readFile ./artifacts.json);

  jormungandr = inputs.jormungandr.packages.${final.system}.jormungandr;

  jormungandr-monitor =
    final.callPackage (inputs.jormungandr-nix + "/nixos/jormungandr-monitor") {
      jormungandr-cli = final.jormungandr;
    };

  vit-servicing-station = final.callPackage ./pkgs/vit-servicing-station.nix {
    vit-servicing-station =
      inputs.vit-servicing-station.packages.${final.system}.vit-servicing-station;
  };

  jormungandr-entrypoint = final.callPackage ./pkgs/jormungandr.nix { };

  print-env = final.callPackage ./pkgs/print-env.nix { };

  jormungandr-monitor-entrypoint =
    final.callPackage ./pkgs/jormungandr-monitor.nix { };

  restic-backup = final.callPackage ./pkgs/restic-backup { };

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
}
