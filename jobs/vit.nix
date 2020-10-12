{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib, block0, db
, vit-servicing-station, wget, gzip, gnutar, cacert }:
let
  run-vit = writeShellScript "vit" ''
    set -exuo pipefail

    home="''${NOMAD_ALLOC_DIR}"
    cd $home

    db="''${NOMAD_ALLOC_DIR}/database.db"
    cp ${db} "$db"
    chmod u+wr "$db"

    ${vit-servicing-station}/bin/vit-servicing-station-server \
      --block0-path ${block0} --db-url "$db"
  '';

  run-jormungandr = args:
    writeShellScript "jormungandr" ''
      set -exuo pipefail

      cd "''${NOMAD_ALLOC_DIR}"

      wget -O jormungandr.tar.gz https://github.com/input-output-hk/jormungandr/releases/download/nightly.20200903/jormungandr-0.9.1-nightly.20200903-x86_64-unknown-linux-musl-generic.tar.gz
      tar --no-same-permissions xvf jormungandr.tar.gz
      exec ./jormungandr ${toString args}
    '';

  env = {
    PATH = lib.makeBinPath [ coreutils wget gnutar gzip ];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  resources = {
    cpu = 100; # mhz
    memoryMB = 1 * 1024;
  };

  genesis = "d5a882ea91947a2160557671991b5349f440d5e4a603f814f0b9ee3d01f6dd8e";

  vit-servicing-station-server-config = {
    address = "0.0.0.0:3030";
    tls = {
      cert_file = null;
      priv_key_file = null;
    };
    cors = {
      allowed_origins = [ "https://api.vit.iohk.io" "http://127.0.0.1" ];
      max_age_secs = null;
    };
    db_url = "./db/database.sqlite3";
    block0_path = "./resources/v0/block0.bin";
    enable_api_tokens = false;
    log = {
      log_output_path = "vsss.log";
      log_level = "info";
    };
  };

  mkVitConfig = peers:
    let
      original = builtins.toJSON {
        bootstrap_from_trusted_peers = true;
        explorer = { enabled = false; };
        leadership = { logs_capacity = 1024; };
        log = [{
          format = "plain";
          level = "info";
          output = "stdout";
        }];

        mempool = {
          log_max_entries = 100000;
          pool_max_entries = 100000;
        };

        p2p = {
          allow_private_addresses = true;
          layers = {
            preferred_list = {
              peers = map (p: { address = p; }) peers;
              view_max = 20;
            };
          };
          listen_address = ''/ip4/127.0.0.1/tcp/{{ env "NOMAD_PORT_rpc" }}'';
          max_bootstrap_attempts = 3;
          max_client_connections = 192;
          max_connections = 256;
          max_unreachable_nodes_to_connect_per_event = 20;
          policy = {
            quarantine_duration = "5s";
            quarantine_whitelist = peers;
          };
          public_address = ''/ip4/127.0.0.1/tcp/{{ env "NOMAD_PORT_rpc" }}'';
          topics_of_interest = {
            blocks = "high";
            messages = "high";
          };
          trusted_peers = map (p: { address = p; }) peers;
        };

        rest = { listen = "127.0.0.1:8001"; };
        skip_bootstrap = false;
        storage = "storage";
      };
    in lib.replaceStrings [ ''{{ env \"'' ''\" }}'' ] [ ''{{ env "'' ''" }}'' ]
    original;

  mkVit = num:
    let
      localBindPort = 7000 + num;
      name = "vit-node-leader-${toString num}";

      upstreams = [
        {
          destinationName = "vit-node-leader-0";
          localBindPort = 7000;
        }
        {
          destinationName = "vit-node-leader-1";
          localBindPort = 7001;
        }
        {
          destinationName = "vit-node-leader-2";
          localBindPort = 7002;
        }
      ];

      peers = lib.pipe upstreams [
        (lib.filter (upstream: upstream.destinationName != name))
        (map
          (upstreams: "/ip4/127.0.0.1/tcp/${toString upstreams.localBindPort}"))
      ];
    in {
      ${name} = {
        count = 1;

        networks = [{ mode = "bridge"; }];

        services.${name} = {
          name = "rpc";
          portLabel = "9001";

          connect.sidecarService = { proxy = { inherit upstreams; }; };
        };

        tasks.${name} = {
          driver = "docker";

          # vault.policies = [ "nomad-cluster" ];

          config = {
            image = "docker.vit.iohk.io/vit:latest";
            command = "jormungandr";
            args = [
              "--config"
              "local/node-config.yaml"
              "--genesis-block"
              "local/block0.bin"
              "--secret"
              "local/bft-secret.yaml"
            ];
          };

          # templates = [
          #   {
          #     data = mkVitConfig peers;
          #     destination = "local/node-config.yaml";
          #   }
          #   {
          #     data = ''
          #       genesis:

          #       bft:
          #         signing_key: {{with secret "kv/data/nomad-cluster/bft/0"}}{{.Data.data.value}}{{end}}
          #     '';
          #     destination = "local/bft-secret.yaml";
          #   }
          # ];

          inherit env resources;
        };
      };
    };
in {
  vit = mkNomadJob "vit" {
    datacenters = [ "us-east-2" ];
    type = "service";

    taskGroups = {
      vit-servicing-station = {
        count = 0;

        services.vit-servicing-station = { };

        tasks.vit-servicing-station = systemdSandbox {
          name = "vit-servicing-station";
          command = run-vit;

          env = { PATH = lib.makeBinPath [ coreutils ]; };

          resources = {
            cpu = 100;
            memoryMB = 1 * 1024;
          };
        };
      };
    } // (mkVit 0) // (mkVit 1) // (mkVit 2);
  };
}
