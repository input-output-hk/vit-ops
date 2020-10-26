{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib
, vit-servicing-station, cacert, curl, dnsutils, gawk, gnugrep, iproute, jq
, lsof, netcat, nettools, procps, jormungandr-monitor, jormungandr, telegraf
, remarshal }:
let
  jobPrefix = "vit-testnet";

  jormungandr-version = "0.10.0-alpha.1";

  env = {
    # Adds some extra commands to the store and path for debugging inside
    # nomad jobs with `nomad alloc exec $ALLOC_ID /bin/sh`
    PATH = lib.makeBinPath [
      coreutils
      curl
      dnsutils
      gawk
      gnugrep
      iproute
      jq
      lsof
      netcat
      nettools
      procps
      jormungandr
      remarshal
    ];
  };

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

  mkVitConfig = { public, explorer ? false, skipBootstrap ? false }: ''
    {
      "bootstrap_from_trusted_peers": true,
      "explorer": {
        "enabled": ${lib.boolToString explorer}
      },
      "leadership": {
        "logs_capacity": 1024
      },
      "log": [
        {
          "format": "plain",
          "level": "info",
          "output": "stdout"
        }
      ],
      "mempool": {
        "log_max_entries": 100000,
        "pool_max_entries": 100000
      },
      "p2p": {
        "allow_private_addresses": true,
        "layers": {
          "preferred_list": {
            "peers": [
              {{ range $index, $service := service "${jobPrefix}-node-leader" }}
                {{ if ne $index 0 }},{{ end }}
                { "address": "/ip4/{{ $service.Address }}/tcp/{{ $service.Port }}" }
              {{ end }}
            ],
            "view_max": 20
          }
        },
        "listen_address": "/ip4/{{ env "NOMAD_IP_rpc" }}/tcp/{{ env "NOMAD_PORT_rpc" }}",
        "max_bootstrap_attempts": 3,
        "max_client_connections": 192,
        "max_connections": 256,
        "max_unreachable_nodes_to_connect_per_event": 20,
        "policy": {
          "quarantine_duration": "5s",
          "quarantine_whitelist": [
            {{ range $index, $service := service "${jobPrefix}-node-leader" }}
              {{ if ne $index 0 }},{{ end }}
              "/ip4/{{ $service.Address }}/tcp/{{ $service.Port }}"
            {{ end }}
          ]
        },
        "public_address": "/ip4/{{ env "NOMAD_IP_rpc" }}/tcp/{{ env "NOMAD_PORT_rpc" }}",
        "topics_of_interest": {
          "blocks": "high",
          "messages": "high"
        },
        "trusted_peers": [
          {{ range $index, $service := service "${jobPrefix}-node-leader" }}
            {{ if ne $index 0 }},{{ end }}
            { "address": "/ip4/{{ $service.Address }}/tcp/{{ $service.Port }}" }
          {{ end }}
        ]
      },
      "rest": {
        "listen": "{{ env "NOMAD_IP_rest" }}:{{ env "NOMAD_PORT_rest" }}"
      },
      "skip_bootstrap": ${lib.boolToString skipBootstrap}
    }
  '';

  mkVit = { index, requiredPeerCount, public ? false }:
    let
      localRpcPort = (if public then 10000 else 7000) + index;
      localRestPort = (if public then 11000 else 9000) + index;
      publicPort = 7100 + index;

      prefix = if public then
        "${jobPrefix}-node-follower"
      else
        "${jobPrefix}-node-leader";
      name = if public then
        "${prefix}-${toString index}"
      else
        "${prefix}-${toString index}";
    in {
      ${name} = {
        count = 1;

        networks = [{ mode = "bridge"; }];

        tasks."${name}-monitor" = systemdSandbox {
          name = "${name}-monitor";

          resources = {
            cpu = 100; # mhz
            memoryMB = 256;
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
            export JORMUNGANDR_API="http://$NOMAD_ADDR_${
              lib.replaceStrings [ "-" ] [ "_" ] name
            }_rest/api";

            exec ${jormungandr-monitor}
          '';
        };

        tasks."${name}-telegraf" = systemdSandbox {
          name = "${name}-telegraf";

          vault.policies = [ "nomad-cluster" ];

          resources = {
            cpu = 100; # mhz
            memoryMB = 128;
            networks = [{ dynamicPorts = [{ label = "prometheus"; }]; }];
          };

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

              # NOMAD_ADDR_${
                lib.replaceStrings [ "-" ] [ "_" ] name
              }_monitor_prometheus

              urls = [ "http://{{ env "NOMAD_ADDR_${
                lib.replaceStrings [ "-" ] [ "_" ] name
              }_monitor_prometheus" }}" ]

              [outputs.influxdb]
              database = "telegraf"
              urls = ["http://monitoring.node.consul:8428"]
            '';
            destination = "local/telegraf.config";
          }];
        };

        tasks.${prefix} = systemdSandbox {
          inherit name env;
          mountPaths = { "${jobPrefix}" = "/persistent"; };

          services.${prefix} = {
            portLabel = "rpc";
            tags = lib.optionals public [ "ingress" name ];
            meta = lib.optionalAttrs public {
              ingressHost = "${name}.vit.iohk.io";
              ingressPort = toString publicPort;
              ingressBind = "*:${toString publicPort}";
              ingressMode = "tcp";
              ingressServer = "_${name}._tcp.service.consul";
              ingressBackendExtra = ''
                option tcplog
              '';
            };
          };

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 1024;
            networks =
              [{ dynamicPorts = [ { label = "rpc"; } { label = "rest"; } ]; }];
          };

          vault.policies = [ "nomad-cluster" ];

          command = writeShellScript "jormungandr" ''
            set -exuo pipefail

            cd "$NOMAD_TASK_DIR"

            export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
            storage="$NOMAD_TASK_DIR/persistent/${name}/storage"
            mkdir -p "$storage"

            set +x
            echo "waiting for ${toString requiredPeerCount} peers"
            until [ "$(jq -r '.p2p.trusted_peers | length' < node-config.json)" -ge ${
              toString requiredPeerCount
            } ]; do
              sleep 0.1
            done
            set -x

            remarshal --if json --of yaml node-config.json > running.yaml

            chown --reference . --recursive . || true

            exec jormungandr \
              --storage "$storage" \
              --config "$NOMAD_TASK_DIR/running.yaml" \
              --genesis-block $NOMAD_TASK_DIR/block0.bin/block0.bin \
              ${
                lib.optionalString (!public)
                "--secret $NOMAD_TASK_DIR/bft-secret.yaml"
              }
          '';

          artifacts = [{
            source =
              "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
            destination = "local/block0.bin";
          }];

          templates = [{
            data = mkVitConfig {
              inherit public;
              skipBootstrap = requiredPeerCount == 0;
            };
            changeMode = "noop";
            destination = "local/node-config.json";
          }] ++ (lib.optional (!public) {
            data = ''
              genesis:
              bft:
                signing_key: {{with secret "kv/data/nomad-cluster/bft/${
                  toString index
                }"}}{{.Data.data.value}}{{end}}
            '';
            destination = "local/bft-secret.yaml";
          });
        };
      };
    };
in {
  ${jobPrefix} = mkNomadJob jobPrefix {
    datacenters = [ "eu-central-1" "us-east-2" ];
    type = "service";

    taskGroups = {
      "${jobPrefix}-servicing-station" = {
        count = 1;

        tasks."${jobPrefix}-servicing-station" = systemdSandbox {
          name = "${jobPrefix}-servicing-station";
          mountPaths = { "${jobPrefix}" = "/persistent"; };
          command = writeShellScript "vit-servicing-station" ''
            set -exuo pipefail

            cd "$NOMAD_TASK_DIR"

            db="$NOMAD_TASK_DIR/persistent/db/database.sqlite3"
            mkdir -p "$(dirname "$db")"
            cp "$NOMAD_TASK_DIR/database.sqlite3/database.sqlite3" "$db"
            chmod u+wr "$db"

            ${vit-servicing-station}/bin/vit-servicing-station-server \
              --block0-path "$NOMAD_TASK_DIR/block0.bin/block0.bin" \
              --db-url "$db" \
              --address "$NOMAD_ADDR_web"
          '';

          services."${jobPrefix}-servicing-station" = {
            portLabel = "web";
            tags = [ "ingress" jobPrefix ];
            meta = {
              ingressHost = "servicing-station.vit.iohk.io";
              ingressCheck = ''
                http-check send meth GET uri /api/v0/graphql/playground
                http-check expect status 200
              '';
              ingressMode = "http";
              ingressBind = "*:443";
              # ingressIf = "{ path_beg /api }";
              ingressServer =
                "_${jobPrefix}-servicing-station._tcp.service.consul";
            };
          };

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 512;
            networks = [{ dynamicPorts = [{ label = "web"; }]; }];
          };

          artifacts = [
            {
              source =
                "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
              destination = "local/block0.bin";
            }
            {
              source =
                "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/database.sqlite3";
              destination = "local/database.sqlite3";
            }
          ];

          env = { PATH = lib.makeBinPath [ coreutils ]; };
        };
      };
    } // (mkVit {
      index = 0;
      public = false;
      requiredPeerCount = 0;
    }) // (mkVit {
      index = 1;
      public = false;
      requiredPeerCount = 1;
    }) // (mkVit {
      index = 2;
      public = false;
      requiredPeerCount = 2;
    }) // (mkVit {
      index = 0;
      public = true;
      requiredPeerCount = 3;
    });
  };
}
