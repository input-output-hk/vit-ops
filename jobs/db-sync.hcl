job "db-sync" {
  namespace = "[[ .namespace ]]"
  datacenters = [[ .datacenters | mustToJson ]]
  type = "service"

  constraint {
    attribute = "${attr.unique.platform.aws.instance-id}"
    value     = "[[.dbSyncInstance]]"
  }

  group "db-sync" {
    network {
      mode = "host"
    }

    volume "persist" {
      type = "host"
      read_only = false
      source = "[[ .namespace ]]-db-sync"
    }

    task "db-sync" {
      driver = "exec"

      resources {
        cpu = 700
        memory = 4000
      }

      volume_mount {
        volume      = "persist"
        destination = "/persist"
      }

      config {
        flake = "github:input-output-hk/cardano-db-sync?rev=[[.dbSyncRev]]#cardano-db-sync-extended-mainnet"
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
        cpu = 1900
        memory = 512
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
        cpu = 1800
        memory = 2000
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
  }
}
