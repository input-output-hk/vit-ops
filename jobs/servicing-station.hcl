job "servicing-station" {
  namespace = "[[ .namespace ]]"
  datacenters = [[ .datacenters | mustToJson ]]
  type = "service"

  group "servicing-station" {
    network {
      mode = "host"
      port "web" {}
      port "promtail" {}
    }

    service {
      name = "[[.namespace]]-servicing-station"
      address_mode = "host"
      port = "web"
      tags = [ "ingress", "[[.namespace]]" ]

      check {
        type = "http"
        port = "web"
        interval = "10s"
        path = "/api/v0/graphql/playground"
        timeout = "2s"
      }

      meta {
        IngressHost = "[[.domain]]"
        IngressMode = "http"
        IngressBind = "*:443"
        IngressIf = "{ path_beg /api/v0/block0 /api/v0/fund /api/v0/proposals /api/v0/graphql/playground /api/v0/graphql /api/v0/challenges }"
        IngressServer = "_[[.namespace]]-servicing-station._tcp.service.consul"
        IngressCheck = <<-EOS
        http-check send meth GET uri /api/v0/graphql/playground
        http-check expect status 200
        EOS
        UngressBackendExtra = <<-EOS
        acl is_origin_null req.hdr(Origin) -i null
        http-request del-header Origin if is_origin_null
        EOS
      }
    }

    service {
      name = "[[.namespace]]-servicing-station-jormungandr"
      address_mode = "host"
      port = "web"
      tags = [ "ingress", "[[.namespace]]" ]
      check {
        type = "http"
        port = "web"
        interval = "10s"
        path = "/api/v0/graphql/playground"
        timeout = "2s"
      }

      meta {
        IngressHost = "[[.domain]]"
        IngressMode = "http"
        IngressBind = "*:443"
        IngressIf = "{ path_beg /api/v0/account /api/v0/message /api/v0/settings /api/v0/vote }"
        IngressServer = "_[[.namespace]]-follower-0-jormungandr-rest._tcp.service.consul"
        IngressCheck = <<-EOS
        http-check send meth GET uri /api/v0/node/stats
        http-check expect status 200
        EOS
        IngressBackendExtra = <<-EOS
        acl is_origin_null req.hdr(Origin) -i null
        http-request del-header Origin if is_origin_null
        EOS
      }
    }

    task "servicing-station" {
      driver = "exec"

      config {
        flake = "github:input-output-hk/vit-ops?rev=[[.vitOpsRev]]#vit-servicing-station"
        command = "/bin/vit-servicing-station-server"
        args = [ "--in-settings-file", "local/station-config.yaml" ]
      }

      env {
        PATH = "/bin"
      }

      resources {
        cpu = 100
        memory = 512
      }

      template {
        destination = "local/station-config.yaml"
        data = <<-EOS
        {
          "tls": {
            "cert_file": null,
            "priv_key_file": null
          },
          "cors": {
            "allowed_origins": [ "https://[[.domain]]", "http://127.0.0.1" ],
            "max_age_secs": null
          },
          "db_url": "local/database.sqlite3/database.sqlite3",
          "block0_path": "local/block0.bin/block0.bin",
          "enable_api_tokens": false,
          "log": {
            "log_level": "debug"
          },
          "address": "0.0.0.0:{{ env "NOMAD_PORT_web" }}"
        }
        EOS
      }

      [[ with $artifact := get (fileContents "./artifacts.json" | parseJSON) .namespace ]]
        artifact {
          destination = "local/block0.bin"
          source = "[[ $artifact.block0.url ]]"
          options {
            checksum = "[[ $artifact.block0.checksum ]]"
          }
        }

        artifact {
          destination = "local/database.sqlite3"
          source = "[[ $artifact.database.url ]]"
          options {
            checksum = "[[ $artifact.database.checksum ]]"
          }
        }
      [[ end ]]
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
        data = <<-EOS
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
        EOS
      }
    }
  }
}
