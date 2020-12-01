{ dockerImages, namespace, name, block0 }: {
  driver = "docker";
  vault.policies = [ "nomad-cluster" ];

  resources = {
    cpu = 100;
    memoryMB = 128;
  };

  config = {
    image = dockerImages.backup.id;
    args = [ "--tag" namespace ];
    ports = [ "rpc" "rest" ];

    labels = [{
      inherit namespace name;
      imageTag = dockerImages.backup.image.imageTag;
    }];

    logging = {
      type = "journald";
      config = [{
        tag = name;
        labels = "name,namespace,imageTag";
      }];
    };
  };

  artifacts = [ block0 ];

  templates = [
    {
      data = ''
        AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
        AWS_DEFAULT_REGION="us-east-1"
        AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
        RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
        RESTIC_REPOSITORY="s3:http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
      '';
      env = true;
      destination = "secrets/env.txt";
    }
    {
      data = let
        peers = ''
          {{ range $index, $service := service "${namespace}-jormungandr" }}
            {{if ne $index 0}},{{end}} "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}"
          {{ end }}
        '';

        peerAddresses = ''
          {{ range $index, $service := service "${namespace}-jormungandr" }}
            {{if ne $index 0}},{{end}} { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
          {{ end }}
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
          "skip_bootstrap": false
        }
      '';
      changeMode = "noop";
      destination = "local/node-config.json";
    }
  ];
}
