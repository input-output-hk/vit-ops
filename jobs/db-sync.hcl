job "db-sync" {
  namespace = "[[ .namespace ]]"
  datacenters = [[ .datacenters | toJson ]]
  type = "service"

  constraint {
    attribute = "${attr.unique.platform.aws.instance-id}"
    value     = "[[.dbSyncInstance]]"
  }

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = false
    auto_promote      = false
    canary            = 0
    stagger           = "30s"
  }

  group "db-sync" {
    network {
      mode = "host"
    }

    count = 1

    volume "persist" {
      type = "host"
      read_only = false
      source = "[[ .namespace ]]-db-sync"
    }

    task "db-sync" {
      driver = "exec"

      resources {
        cpu = 13600
        memory = 8000
      }

      volume_mount {
        volume      = "persist"
        destination = "/persist"
      }

      config {
        flake = "github:input-output-hk/cardano-db-sync?rev=[[.dbSyncRev]]#cardano-db-sync-extended-[[.dbSyncNetwork]]"
        command = "/bin/cardano-db-sync-extended-entrypoint"
      }

      env {
        CARDANO_NODE_SOCKET_PATH = "/alloc/node.socket"
        PATH = "/bin"
      }
    }

    task "postgres" {
      driver = "exec"

      resources {
        cpu = 13600
        memory = 1000
      }

      volume_mount {
        volume      = "persist"
        destination = "/persist"
      }

      config {
        flake = "github:input-output-hk/cardano-db-sync?rev=[[.dbSyncRev]]#postgres"
        command = "/bin/postgres-entrypoint"
      }

      env {
        PGDATA = "/persist/postgres"
        PATH = "/bin"
      }
    }

    task "cardano-node" {
      driver = "exec"

      resources {
        cpu = 13600
        memory = 3000
      }

      volume_mount {
        volume      = "persist"
        destination = "/persist"
      }

      config {
        flake = "github:input-output-hk/cardano-node?rev=14229feb119cc3431515dde909a07bbf214f5e26#cardano-node-mainnet-debug"
        command = "/bin/cardano-node-entrypoint"
      }

      env {
        PATH = "/bin"
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
         - job_name: db-sync-[[.dbSyncNetwork]]
           pipeline_stages:
           static_configs:
           - labels:
              syslog_identifier: db-sync-[[.dbSyncNetwork]]
              namespace: [[.namespace]]
              dc: {{ env "NOMAD_DC" }}
              host: {{ env "HOSTNAME" }}
              __path__: /alloc/logs/*.std*.0
        YAML
      }
    }

  }
}
