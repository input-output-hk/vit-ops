inputs:
final: prev:
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
    (inputs.jormungandr-nix + "/nixos/jormungandr-monitor") {
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
}
