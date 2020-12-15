{ lib, dockerImages, namespace, name, requiredPeerCount, public, index, block0
}: {
  driver = "docker";

  vault = {
    policies = [ "nomad-cluster" ];
    changeMode = "noop";
  };

  killSignal = "SIGINT";

  restartPolicy = {
    interval = "15m";
    attempts = 5;
    delay = "1m";
    mode = "delay";
  };

  config = {
    image = dockerImages.jormungandr;
    ports = [ "rpc" "rest" ];
    labels = [{
      inherit namespace name;
      imageTag = dockerImages.jormungandr.image.imageTag;
    }];

    logging = {
      type = "journald";
      config = [{
        tag = name;
        labels = "name,namespace,imageTag";
      }];
    };
  };

  env = {
    REQUIRED_PEER_COUNT = toString requiredPeerCount;
    PRIVATE = lib.optionalString (!public) "true";
    STORAGE_DIR = "/local/storage";
    NAMESPACE = namespace;
    RUST_BACKTRACE = "full";
  };

  resources = {
    cpu = 700; # mhz
    memoryMB = 512;
  };

  artifacts = [ block0 ];

  templates = [
    {
      data = let
        eachService = line: ''
          {{ range service "${namespace}-jormungandr-internal" }}
            {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
              {{ scratch.MapSet "vars" .ID . }}
            {{ end }}
          {{ end }}
          [
          {{ range $index, $service := (scratch.MapValues "vars" ) }}
            {{- if ne $index 0}},{{else}} {{end -}}
            ${line}
          {{ end -}}
          ]
        '';

        peers = eachService ''
          "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}"
        '';

        peerAddresses = eachService ''
          { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
        '';
      in ''
        {
          "bootstrap_from_trusted_peers": true,
          "explorer": {
            "enabled": false
          },
          "leadership": {
            "logs_capacity": 1024
          },
          "log": [
            {
              "format": "plain",
              "level": "debug",
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
      changeMode = "noop";
      destination = "local/node-config.json";
    }
    {
      data = ''
        AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
        AWS_DEFAULT_REGION="us-east-1"
        AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
        RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
        RESTIC_REPOSITORY="s3:http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
        RESET="{{with secret "kv/data/nomad-cluster/${namespace}/reset"}}{{.Data.data.value}}{{end}}"
      '';
      env = true;
      destination = "secrets/env.txt";
    }
  ] ++ (lib.optional (!public) {
    data = ''
      genesis:
      bft:
        signing_key: {{with secret "kv/data/nomad-cluster/bft/${
          toString index
        }"}}{{.Data.data.value}}{{end}}
    '';
    destination = "secrets/bft-secret.yaml";
  });
}
