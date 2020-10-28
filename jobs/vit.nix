{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib
, vit-servicing-station, cacert, curl, dnsutils, gawk, gnugrep, iproute, jq
, lsof, netcat, nettools, procps, jormungandr-monitor, jormungandr, telegraf
, remarshal, dockerImages }:
let
  jormungandr-version = "0.10.0-alpha.1";
  jobPrefix = "vit-testnet";

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

  mkVitConfig = { public, explorer ? false, requiredPeerCount }:
    let
      requiredPeers = lib.take requiredPeerCount [
        "${jobPrefix}-leader-0-jormungandr"
        "${jobPrefix}-leader-1-jormungandr"
        "${jobPrefix}-leader-2-jormungandr"
      ];

      singlePeerAddress = peer: ''
        {{ with service "${peer}" -}}{{ with index . 0 }}
        { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
        {{- end }}{{ end }}
      '';

      singlePeer = peer: ''
        {{ with service "${peer}" -}}{{ with index . 0 }}
        "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}"
        {{- end }}{{ end }}
      '';

      peerAddresses = lib.concatStringsSep ''
        ,
      '' (lib.forEach requiredPeers singlePeerAddress);

      peers = lib.concatStringsSep ''
        ,
      '' (lib.forEach requiredPeers singlePeer);
    in ''
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
                ${peerAddresses}
              ],
              "view_max": 20
            }
          },
          "listen_address": "/ip4/0.0.0.0/tcp/{{ env "NOMAD_PORT_rpc" }}",
          "max_bootstrap_attempts": 3,
          "max_client_connections": 192,
          "max_connections": 256,
          "max_unreachable_nodes_to_connect_per_event": 20,
          "policy": {
            "quarantine_duration": "5s",
            "quarantine_whitelist": [
              ${peers}
            ]
          },
          "public_address": "/ip4/{{ env "NOMAD_HOST_IP_rpc" }}/tcp/{{ env "NOMAD_HOST_PORT_rpc" }}",
          "topics_of_interest": {
            "blocks": "high",
            "messages": "high"
          },
          "trusted_peers": [
            ${peerAddresses}
          ]
        },
        "rest": {
          "listen": "0.0.0.0:{{ env "NOMAD_PORT_rest" }}"
        },
        "skip_bootstrap": ${lib.boolToString (requiredPeerCount == 0)}
      }
    '';

  mkVit = { index, requiredPeerCount, public ? false }:
    let
      localRpcPort = (if public then 10000 else 7000) + index;
      localRestPort = (if public then 11000 else 9000) + index;
      localPrometheusPort = 10000 + index;
      publicPort = 7100 + index;

      name = if public then
        "follower-${toString index}"
      else
        "leader-${toString index}";
    in {
      ${name} = {
        count = 1;

        volumes.${name} = {
          type = "host";
          source = "vit-testnet";
        };

        networks = [{
          ports = {
            prometheus.to = 7000;
            rest.to = localRestPort;
            rpc.to = localRpcPort;
          };
        }];

        services."\${JOB}-${name}-monitor" = {
          portLabel = "prometheus";
          task = "monitor";
        };

        tasks.monitor = {
          driver = "docker";

          resources = {
            cpu = 100; # mhz
            memoryMB = 256;
          };

          config = {
            image = dockerImages.monitor.id;
            ports = [ "prometheus" ];
          };

          templates = [{
            data = ''
              SLEEP_TIME="10"
              PORT="{{ env "NOMAD_PORT_prometheus" }}"
              JORMUNGANDR_API="http://{{ env "NOMAD_ADDR_rest" }}/api"
            '';
            env = true;
            destination = "local/env.txt";
          }];
        };

        tasks.telegraf = {
          driver = "docker";

          vault.policies = [ "nomad-cluster" ];

          resources = {
            cpu = 100; # mhz
            memoryMB = 128;
          };

          config = {
            image = dockerImages.telegraf.id;
            args = [ "-config" "local/telegraf.config" ];
          };

          templates = [{
            data = let upstreamName = lib.replaceStrings [ "-" ] [ "_" ] name;
            in ''
              [agent]
              flush_interval = "10s"
              interval = "10s"
              omit_hostname = false

              [global_tags]
              client_id = "${name}"

              [inputs.prometheus]
              metric_version = 1

              urls = [ "http://{{ env "NOMAD_ADDR_prometheus" }}" ]

              [outputs.influxdb]
              database = "telegraf"
              urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
            '';
            destination = "local/telegraf.config";
          }];
        };

        services."\${JOB}-${name}-jormungandr" = {
          addressMode = "host";
          portLabel = "rpc";
          task = "jormungandr";
          tags = [ name (if public then "follower" else "leader") ]
            ++ (lib.optional public "ingress");
          meta = lib.optionalAttrs public {
            ingressHost = "${name}.vit.iohk.io";
            ingressPort = toString publicPort;
            ingressBind = "*:${toString publicPort}";
            ingressMode = "tcp";
            ingressServer = "_${jobPrefix}-${name}-jormungandr._tcp.service.consul";
            ingressBackendExtra = ''
              option tcplog
            '';
          };
        };

        tasks.jormungandr = {
          driver = "docker";

          vault.policies = [ "nomad-cluster" ];

          config = {
            image = dockerImages.jormungandr.id;
            ports = [ "rpc" "rest" ];
          };

          env = {
            REQUIRED_PEER_COUNT = toString requiredPeerCount;
            PRIVATE = lib.optionalString (!public) "true";
            STORAGE_DIR = "/persist/${name}";
          };

          resources = {
            cpu = 700; # mhz
            memoryMB = 100;
          };

          volumeMounts.${name} = {
            readOnly = false;
            destination = "/persist";
          };

          artifacts = [{
            source =
              "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
            destination = "local/block0.bin";
          }];

          templates = [{
            data = mkVitConfig { inherit public requiredPeerCount; };
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
            destination = "secrets/bft-secret.yaml";
          });
        };
      };
    };
in {
  ${jobPrefix} = mkNomadJob jobPrefix {
    datacenters = [ "eu-central-1" "us-east-2" ];
    type = "service";
    namespace = jobPrefix;

    taskGroups = {
      "${jobPrefix}-servicing-station" = {
        count = 1;

        networks = [{ ports = { web = { }; }; }];

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

        tasks.servicing-station = {
          driver = "docker";

          config = {
            image = dockerImages.vit-servicing-station.id;
            args = [
              "--block0-path"
              "local/block0.bin/block0.bin"
              "--db-url"
              "local/database.sqlite3/database.sqlite3"
              "--address"
              "0.0.0.0:\${NOMAD_PORT_web}"
            ];
            ports = [ "web" ];
          };

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 512;
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
