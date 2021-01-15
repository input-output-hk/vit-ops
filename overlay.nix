inputs: final: prev:
let lib = final.lib;
in {
  rev =
    self.rev or (builtins.throw "please commit and push before invoking jobs");

  consul-templates = let
    sources = lib.pipe final.nomadJobs [
      (lib.filterAttrs (n: v: v ? evaluated))
      (lib.mapAttrsToList (n: v: {
        path = [ n v.evaluated.Job.Namespace ];
        taskGroups = v.evaluated.Job.TaskGroups;
      }))
      (map (e:
        map (tg:
          map (t:
            if t.Templates != null then
              map (tpl: {
                name = lib.concatStringsSep "/"
                  (e.path ++ [ tg.Name t.Name tpl.DestPath ]);
                tmpl = tpl.EmbeddedTmpl;
              }) t.Templates
            else
              null) tg.Tasks) e.taskGroups))
      builtins.concatLists
      builtins.concatLists
      (lib.filter (e: e != null))
      builtins.concatLists
      (map (t: {
        name = t.name;
        path = final.writeText t.name t.tmpl;
      }))
    ];
  in final.linkFarm "consul-templates" sources;

  inherit (final.dockerTools) buildLayeredImage;

  mkEnv = lib.mapAttrsToList (key: value: "${key}=${value}");

  jormungandr-monitor =
    final.callPackage (inputs.jormungandr-nix + "/nixos/jormungandr-monitor") {
      jormungandr-cli = final.jormungandr;
    };

  vit-servicing-station = final.callPackage ./pkgs/vit-servicing-station.nix {
    vit-servicing-station =
      inputs.vit-servicing-station.packages.${final.system}.vit-servicing-station;
  };
  jormungandr = final.callPackage ./pkgs/jormungandr.nix { };
  print-env = final.callPackage ./pkgs/print-env.nix { };
  jormungandr-monitor-entrypoint =
    final.callPackage ./pkgs/jormungandr-monitor.nix { };

  restic-backup = final.callPackage ./pkgs/restic-backup { };
  restic = inputs.nixpkgs-unstable.legacyPackages.${final.system}.restic;

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
