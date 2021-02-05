[[ $name := printf "%s-%s" .role .index ]]
[[ $id := printf "%s-%s" .namespace $name ]]
[[ $publicPort := add 7200 .index ]]

job "[[$name]]" {
  namespace = "[[ .namespace ]]"
  datacenters = [[ .datacenters ]]
  type = "service"

  group "jormungandr" {
    network {
      mode = "host"
      port prometheus {}
      port rest {}
      port rpc {}
      port promtail {}
    }

    ephemeral_disk {
      size = 1024
      migrate = true
      sticky = true
    }

    task "jormungandr" {
      driver = "exec"

      vault {
        policies = [ "nomad-cluster" ]
        change_mode = "noop"
      }

      kill_signal = "SIGINT"

      restart {
        interval = "15m"
        attempts = 5
        delay = "1m"
        mode = "delay"
      }

      resources {
        cpu = 700
        memory = 512
      }

      config {
        flake = "github:input-output-hk/vit-ops?rev=[[.vitOpsRev]]#jormungandr-entrypoint"
        command = "/bin/entrypoint"
      }

      env {
        PATH = "/bin"
        NAMESPACE = "[[.namespace]]"
        PRIVATE = "[[ eq .role "leader" ]]"
        REQUIRED_PEER_COUNT = [[ .requiredPeerCount ]]
        RUST_BACKTRACE = "full"
        STORAGE_DIR = "/local/storage"
        AWS_DEFAULT_REGION = "us-east-1"
      }

      template {
        destination = "local/node-config.json"
        change_mode = "noop"
        data = <<-JSON
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
                  {{ range service "[[.namespace]]-jormungandr-internal" }}
                    {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
                      {{ scratch.MapSet "vars" .ID . }}
                    {{ end }}
                  {{ end }}
                  {{ range $index, $service := (scratch.MapValues "vars" ) }}
                    {{- if ne $index 0}},{{else}} {{end -}}
                    { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
                  {{ end -}}
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
                {{ range service "[[.namespace]]-jormungandr-internal" }}
                  {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
                    {{ scratch.MapSet "vars" .ID . }}
                  {{ end }}
                {{ end }}
                {{ range $index, $service := (scratch.MapValues "vars" ) }}
                  {{- if ne $index 0}},{{else}} {{end -}}
                  "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}"
                {{ end -}}
              ]
            },
            "public_address": "/ip4/{{ env "NOMAD_HOST_IP_rpc" }}/tcp/{{ env "NOMAD_HOST_PORT_rpc" }}",
            "topics_of_interest": {
              "blocks": "high",
              "messages": "high"
            },
            "trusted_peers": [
              {{ range service "[[.namespace]]-jormungandr-internal" }}
                {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
                  {{ scratch.MapSet "vars" .ID . }}
                {{ end }}
              {{ end }}
              {{ range $index, $service := (scratch.MapValues "vars" ) }}
                {{- if ne $index 0}},{{else}} {{end -}}
                { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
              {{ end -}}
            ]
          },
          "rest": {
            "listen": "0.0.0.0:{{ env "NOMAD_PORT_rest" }}"
          },
          "skip_bootstrap": [[ eq "0" .requiredPeerCount ]]
        }
        JSON
      }

      template {
        destination = "secrets/env.txt"
        env = true
        change_mode = "noop"
        data = <<-ENV
        AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
        AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
        RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
        RESTIC_REPOSITORY="s3:http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:9000/restic"
        RESET="{{with secret "kv/data/nomad-cluster/[[.namespace]]/reset"}}{{.Data.data.value}}{{end}}"
        ENV
      }

      template {
        destination = "secrets/bft-secret.yaml"
        data = <<-YAML
        genesis:
        bft:
          signing_key: {{with secret "kv/data/nomad-cluster/bft/[[.namespace]]/[[.index]]"}}{{.Data.data.value}}{{end}}
        YAML
      }

      [[ with $artifact := get (fileContents "./artifacts.json" | parseJSON) .namespace ]]
        artifact {
          destination = "local/block0.bin"
          source = "[[ $artifact.block0.url ]]"
          options {
            checksum = "[[ $artifact.block0.checksum ]]"
          }
        }
      [[ end ]]
    }

    task "monitor" {
      driver = "exec"

      resources {
        cpu = 100
        memory = 256
      }

      config {
        flake =
          "github:input-output-hk/vit-ops?rev=[[.vitOpsRev]]#jormungandr-monitor-entrypoint"
        command = "/bin/entrypoint"
        args = [ "-config", "local/telegraf.config" ]
      }

      env {
        SLEEP_TIME = "10"
      }

      template {
        destination = "local/env.txt"
        env = true
        change_mode = "restart"
        data = <<-ENV
          PORT="{{ env "NOMAD_PORT_prometheus" }}"
          JORMUNGANDR_API="http://{{ env "NOMAD_ADDR_rest" }}/api"
        ENV
      }
    }

    task "telegraf" {
      driver = "exec"

      resources {
        cpu = 100
        memory = 128
      }

      config {
        flake = "github:input-output-hk/vit-ops?rev=[[.vitOpsRev]]#telegraf"
        command = "/bin/telegraf"
        args = [ "-config", "local/telegraf.config" ]
      }

      template {
        destination = "local/telegraf.config"
        data = <<-TOML
        [agent]
        flush_interval = "10s"
        interval = "10s"
        omit_hostname = false

        [global_tags]
        client_id = "[[$name]]"
        namespace = "{{ env "NOMAD_NAMESPACE" }}"

        [inputs.prometheus]
        metric_version = 1

        urls = [ "http://127.0.0.1:{{ env "NOMAD_PORT_prometheus" }}" ]

        [outputs.influxdb]
        database = "telegraf"
        urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
        TOML
      }
    }

    task "promtail" {
      driver = "exec"

      config {
        flake = "github:input-output-hk/vit-ops?rev=[[.vitOpsRev]]#grafana-loki"
        command = "/bin/promtail"
        args = [ "-config.file", "local/config.yaml" ]
      }

      template {
        destination = "local/config.yaml"
        data = <<-YAML
        server:
          http_listen_port: {{ env "NOMAD_PORT_promtail" }}
          grpc_listen_port: 0

        positions:
          filename: /local/positions.yaml # This location needs to be writeable by promtail.

        client:
          url: http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:3100/loki/api/v1/push

        scrape_configs:
         - job_name: {{ env "NOMAD_GROUP_NAME" }}
           pipeline_stages:
           static_configs:
           - labels:
              syslog_identifier: {{ env "NOMAD_GROUP_NAME" }}
              namespace: {{ env "NOMAD_NAMESPACE" }}
              dc: {{ env "NOMAD_DC" }}
              host: {{ env "HOSTNAME" }}
              __path__: /alloc/logs/*.std*.0
        YAML
      }
    }

    service {
      name = "[[$id]]" 
      address_mode = "host"
      port = "rpc"
      task = "jormungandr"
      tags = [ "[[$name]]", "[[.role]]", [[ if eq .role "leader" ]]"ingress"[[end]] ]
      [[ if eq .role "follower" ]]
        meta = {
          IngressHost = "[[$name]].vit.iohk.io"
          IngressPort = [[$publicPort]]
          IngressBind = "*:[[$publicPort]]"
          IngressMode = "tcp"
          IngressServer =
            "_[[$id]]._tcp.service.consul"
          IngressBackendExtra = <<-EOS
            option tcplog
          EOS
        }
      [[ end ]]
    }

    service {
      name = "[[$id]]-alloc"
      address_mode = "host"
      port = "3101"
      task = "jormungandr"
    }

    service {
      name = "[[.namespace]]-jormungandr" 
      address_mode = "host"
      port = "rpc"
      task = "jormungandr"
      tags = [ "peer", "[[$name]]", "[[.role]]" ]
    }

    [[ if ne .role "backup" ]]
      service {
        name = "[[.namespace]]-jormungandr-internal" 
        address_mode = "host"
        port = "rpc"
        task = "jormungandr"
        tags = [ "peer", "[[$name]]", "[[.role]]" ]
      }
    [[ end ]]

    service {
      name = "[[$id]]-jormungandr-rest" 
      address_mode = "host"
      port = "rest"
      task = "jormungandr"
      tags = [ "[[$name]]", "[[.role]]" ]

      check {
        type = "http"
        path = "/api/v0/node/stats"
        port = "rest"
        interval = "10s"
        timeout = "1s"

        check_restart {
          limit = 5
          grace = "300s"
          ignore_warnings = false
        }
      }
    }
  }
}
