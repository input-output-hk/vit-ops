{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib, block0, db
, vit-servicing-station, wget, gzip, gnutar, cacert, curl, dnsutils, gawk
, gnugrep, iproute, jq, lsof, netcat, nettools, procps, jormungandr-monitor
, telegraf }:
let
  jobPrefix = "vit-testnet";

  jormungandr-version = "0.9.2-test.1";

  run-vit = writeShellScript "vit" ''
    set -exuo pipefail

    cd "$NOMAD_ALLOC_DIR"

    db="''${NOMAD_ALLOC_DIR}/database.db"
    cp ${db} "$db"
    chmod u+wr "$db"

    ${vit-servicing-station}/bin/vit-servicing-station-server \
      --block0-path ${block0} \
      --db-url "$db" \
      --address "$NOMAD_ADDR_web"
  '';

  run-jormungandr = writeShellScript "jormungandr" ''
    set -exuo pipefail

    cd "$NOMAD_ALLOC_DIR"

    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"

    env

    wget -O jormungandr.tar.gz https://github.com/input-output-hk/jormungandr/releases/download/v${jormungandr-version}/jormungandr-${jormungandr-version}-x86_64-unknown-linux-musl-generic.tar.gz
    tar --no-same-permissions -xvf jormungandr.tar.gz
    exec ./jormungandr \
      --config $NOMAD_TASK_DIR/node-config.yaml \
      --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
      --secret $NOMAD_TASK_DIR/bft-secret.yaml
  '';

  env = {
    # Adds some extra commands to the store and path for debugging inside
    # nomad jobs with `nomad alloc exec $ALLOC_ID /bin/sh`
    PATH = lib.makeBinPath [
      coreutils
      curl
      dnsutils
      gawk
      gnugrep
      gnutar
      gzip
      iproute
      jq
      lsof
      netcat
      nettools
      procps
      wget
    ];
  };

  genesis = "d5a882ea91947a2160557671991b5349f440d5e4a603f814f0b9ee3d01f6dd8e";

  vit-servicing-station-server-config = {
    tls = {
      cert_file = null;
      priv_key_file = null;
    };
    cors = {
      allowed_origins =
        [ "https://servicing-station.vit.iohk.io" "http://127.0.0.1" ];
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

  mkVitConfig = { localRpcPort, localRestPort, peers }:
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
          listen_address = "/ip4/0.0.0.0/tcp/${toString localRpcPort}";
          max_bootstrap_attempts = 3;
          max_client_connections = 192;
          max_connections = 256;
          max_unreachable_nodes_to_connect_per_event = 20;
          policy = {
            quarantine_duration = "5s";
            quarantine_whitelist = peers;
          };
          public_address =
            ''/ip4/{{ env "NOMAD_IP_rpc" }}/tcp/${toString localRpcPort}'';
          topics_of_interest = {
            blocks = "high";
            messages = "high";
          };
          trusted_peers = map (p: { address = p; }) peers;
        };

        rest = { listen = "0.0.0.0:${toString localRestPort}"; };
        skip_bootstrap = false;
        storage = "storage";
      };
      # TODO: this is a pretty hacky fix...
    in lib.replaceStrings [ ''{{ env \"'' ''\" }}'' ] [ ''{{ env "'' ''" }}'' ]
    original;

  mkVit = num:
    let
      localRpcPort = 7000 + num;
      localRestPort = 9000 + num;
      prefix = "${jobPrefix}-node-leader";
      name = "${prefix}-${toString num}";

      nodeUpstreams = [
        {
          destinationName = "${prefix}-0";
          localBindPort = 7000;
        }
        {
          destinationName = "${prefix}-1";
          localBindPort = 7001;
        }
        {
          destinationName = "${prefix}-2";
          localBindPort = 7002;
        }
      ];

      monitorUpstreams = [
        {
          destinationName = "${prefix}-0-monitor";
          localBindPort = 9000;
        }
        {
          destinationName = "${prefix}-1-monitor";
          localBindPort = 9001;
        }
        {
          destinationName = "${prefix}-2-monitor";
          localBindPort = 9002;
        }
      ];

      notSelf =
        lib.filter (upstream: upstream.destinationName != name) nodeUpstreams;

      peers = lib.forEach notSelf
        (upstream: "/ip4/127.0.0.1/tcp/${toString upstream.localBindPort}");
    in {
      ${name} = {
        count = 1;

        networks = [{ mode = "bridge"; }];

        services.${name} = {
          portLabel = toString localRpcPort;
          connect.sidecarService.proxy = { upstreams = nodeUpstreams; };
        };

        services."${name}-monitor" = {
          portLabel = toString localRestPort;
          connect.sidecarService.proxy = { upstreams = monitorUpstreams; };
        };

        tasks."${name}-monitor" = systemdSandbox {
          name = "${name}-monitor";

          resources = {
            networks = [{ dynamicPorts = [{ label = "prometheus"; }]; }];
          };

          services."${name}-monitor-prometheus" = { portLabel = "prometheus"; };

          env = env // { SLEEP_TIME = "10"; };

          command = writeShellScript "vit-monitor" ''
            set -exuo pipefail

            cd "$NOMAD_ALLOC_DIR"

            env

            export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
            export PORT="$NOMAD_PORT_prometheus"
            export JORMUNGANDR_API="http://$NOMAD_UPSTREAM_ADDR_${
              lib.replaceStrings [ "-" ] [ "_" ] name
            }_monitor/api";

            env

            wget -O jormungandr.tar.gz https://github.com/input-output-hk/jormungandr/releases/download/v${jormungandr-version}/jormungandr-${jormungandr-version}-x86_64-unknown-linux-musl-generic.tar.gz
            tar --no-same-permissions -xvf jormungandr.tar.gz
            mkdir -p bin
            mv jcli bin

            exec ${jormungandr-monitor}
          '';
        };

        tasks."${name}-telegraf" = systemdSandbox {
          name = "${name}-telegraf";

          vault.policies = [ "nomad-cluster" ];

          command = writeShellScript "telegraf" ''
            set -exuo pipefail

            ${coreutils}/bin/env

            exec ${telegraf}/bin/telegraf -config $NOMAD_TASK_DIR/telegraf.config
          '';

          templates = [{
            data = ''
              [agent]
              flush_interval = "10s"
              interval = "10s"
              omit_hostname = false

              [global_tags]
              client_id = "${name}"

              [inputs.prometheus]
              metric_version = 1
              urls = [ "http://{{ env "NOMAD_ADDR_${
                lib.replaceStrings [ "-" ] [ "_" ] name
              }_monitor" }}" ]

              [outputs.influxdb]
              database = "telegraf"
              urls = ["http://monitoring.node.consul:8428"]
            '';
            destination = "local/telegraf.config";
          }];
        };

        tasks.${name} = systemdSandbox {
          inherit name env;

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 1024;
            networks = [{
              dynamicPorts = [ { label = "rpc"; } { label = "rest"; } ];
              # reservedPorts = [{
              #   label = "metrics";
              #   value = 13798;
              # }];
            }];
          };

          vault.policies = [ "nomad-cluster" ];
          command = run-jormungandr;

          artifacts = [{
            source =
              "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
            destination = "local/block0.bin";
          }];

          templates = [
            {
              data = mkVitConfig { inherit localRpcPort localRestPort peers; };
              destination = "local/node-config.yaml";
            }
            {
              data = ''
                genesis:
                bft:
                  signing_key: {{with secret "kv/data/nomad-cluster/bft/0"}}{{.Data.data.value}}{{end}}
              '';
              destination = "local/bft-secret.yaml";
            }
          ];
        };
      };
    };
in {
  ${jobPrefix} = mkNomadJob jobPrefix {
    datacenters = [ "us-east-2" ];
    type = "service";

    taskGroups = {
      "${jobPrefix}-servicing-station" = {
        count = 1;

        tasks."${jobPrefix}-servicing-station" = systemdSandbox {
          name = "${jobPrefix}-servicing-station";
          command = run-vit;

          services."${jobPrefix}-servicing-station" = {
            portLabel = "web";
            tags = [ "ingress" jobPrefix ];
            meta = {
              ingressHost = "servicing-station.vit.vit.iohk.io";
              ingressCheck = ''
                http-check send meth GET uri /api/v0/graphql/playground
                http-check expect status 200
              '';
              ingressServer = "_vit-servicing-station._tcp.service.consul";
            };
          };

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 512;
            networks = [{ dynamicPorts = [{ label = "web"; }]; }];
          };

          env = { PATH = lib.makeBinPath [ coreutils ]; };
        };
      };
    } // (mkVit 0) // (mkVit 1) // (mkVit 2);
  };
}
