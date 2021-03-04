package bitte

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#DbSync: types.#stanza.job & {
	_hex:            "[0-9a-f]"
	#dbSyncInstance: =~"^i-\(_hex){17}$"
	#dbSyncNetwork:  "testnet" | "mainnet"
	#dbSyncRev:      =~"^\(_hex){40}$"
	#vitOpsRev:      string
	#domain:         string

	namespace: string
	datacenters: [...string]
	type: "service"

	constraints: [{
		attribute: "${attr.unique.platform.aws.instance-id}"
		value:     #dbSyncInstance
	}]

	update: {
		max_parallel:      1
		health_check:      "checks"
		min_healthy_time:  "10s"
		healthy_deadline:  "5m"
		progress_deadline: "10m"
		auto_revert:       false
		auto_promote:      false
		canary:            0
		stagger:           "30s"
	}

	group: "db-sync": {
		network: {
			mode: "host"
			port: snapshot: {}
		}

		count: 1

		volume: "persist": {
			type:      "host"
			read_only: false
			source:    "\(namespace)-db-sync"
		}

		service: "\(namespace)-snapshot-\(#dbSyncNetwork)": {
			address_mode: "host"
			port:         "snapshot"
			task:         "snapshot"
			tags: [ "ingress", "snapshot", #dbSyncNetwork, namespace]
			meta: {
				IngressHost:   #domain
				IngressMode:   "http"
				IngressBind:   "*:443"
				IngressServer: "_\(namespace)-snapshot-\(#dbSyncNetwork)._tcp.service.consul"
				IngressCheck: """
					http-check send meth GET uri /api/health
					http-check expect status 200
					"""
			}
		}

		task: "db-sync": {
			driver: "exec"

			resources: {
				cpu:    13600
				memory: 8000
			}

			volume_mount: "persist": {
				destination: "/persist"
			}

			config: {
				flake:   "github:input-output-hk/cardano-db-sync?rev=\(#dbSyncRev)#cardano-db-sync-extended-\(#dbSyncNetwork)"
				command: "/bin/cardano-db-sync-extended-entrypoint"
			}

			env: {
				CARDANO_NODE_SOCKET_PATH: "/alloc/node.socket"
				PATH:                     "/bin"
			}
		}

		task: "postgres": {
			driver: "exec"

			resources: {
				cpu:    13600
				memory: 1000
			}

			volume_mount: "persist": {
				destination: "/persist"
			}

			config: {
				flake:   "github:input-output-hk/cardano-db-sync?rev=\(#dbSyncRev)#postgres"
				command: "/bin/postgres-entrypoint"
			}

			env: {
				PGDATA: "/persist/postgres"
				PATH:   "/bin"
			}
		}

		task: "cardano-node": {
			driver: "exec"

			resources: {
				cpu:    13600
				memory: 3000
			}

			volume_mount: "persist": {
				destination: "/persist"
			}

			config: {
				flake:   "github:input-output-hk/cardano-node?rev=14229feb119cc3431515dde909a07bbf214f5e26#cardano-node-\(#dbSyncNetwork)-debug"
				command: "/bin/cardano-node-entrypoint"
			}

			env: {
				PATH: "/bin"
			}
		}

		task: "snapshot": {
			driver: "exec"

			vault: {
				policies: ["nomad-cluster"]
				change_mode: "noop"
			}

			resources: {
				cpu:    6800
				memory: 2 * 1024
			}

			volume_mount: "persist": {
				destination: "/persist"
			}

			config: {
				flake:   "github:input-output-hk/vit-testing/8da3e1db7a79ecadb857fc52b10c6c379eb0f12f#snapshot-trigger-service"
				command: "/bin/snapshot-trigger-service"
				args: ["--config", "/secrets/snapshot.config"]
			}

			template: "genesis-template.json": data: "{}"

			template: "secrets/snapshot.config": {
				left_delimiter:  "[["
				right_delimiter: "]]"
				change_mode: "noop"
				_magic:          string
				if #dbSyncNetwork == "mainnet" {
					_magic: "\"--mainnet\""
				}
				if #dbSyncNetwork == "testnet" {
					_magic: "\"--testnet-magic\", \"1097911063\""
				}

				data: """
        {
          "port": [[ env "NOMAD_PORT_snapshot" ]],
          "result_dir": "/persist/snapshot",
          "command": {
            "bin": "voting-tools",
            "args": [
              "genesis",
              \(_magic),
              "--db", "cexplorer",
              "--db-user", "cexplorer",
              "--db-host", "/alloc",
              "--out-file", "{{RESULT_DIR}}/genesis.yaml",
              "--scale", "1000000",
              "--threshold", "2950000000",
              "--slot-no", "23231709"
            ]
          },
          "token": "[[with secret "kv/data/nomad-cluster/\(namespace)/\(#dbSyncNetwork)/snapshot"]][[.Data.data.token]][[end]]"
        }
        """
			}
		}

		task: "promtail": {
			driver: "exec"

			config: {
				flake:   "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#grafana-loki"
				command: "/bin/promtail"
				args: [ "-config.file", "local/config.yaml"]
			}

			template: "local/config.yaml": {
				data: """
        server:
          http_listen_port: {{ env "NOMAD_PORT_promtail" }}
          grpc_listen_port: 0

        positions:
          filename: /local/positions.yaml # This location needs to be writeable by promtail.

        client:
          url: http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:3100/loki/api/v1/push

        scrape_configs:
         - job_name: db-sync-\(#dbSyncNetwork)
           pipeline_stages:
           static_configs:
           - labels:
              syslog_identifier: db-sync-\(#dbSyncNetwork)
              namespace: \(namespace)
              dc: {{ env "NOMAD_DC" }}
              host: {{ env "HOSTNAME" }}
              __path__: /alloc/logs/*.std*.0
        """
			}
		}
	}
}
