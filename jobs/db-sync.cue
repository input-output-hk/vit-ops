package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
	"list"
)

#DbSync: types.#stanza.job & {
	_hex:                "[0-9a-f]"
	#dbSyncInstance:     =~"^i-\(_hex){17}$"
	#dbSyncNetwork:      "testnet" | "mainnet"
	#dbSyncRev:          =~"^\(_hex){40}$"
	#vitOpsRev:          string
	#snapshotDomain:     string
	#registrationDomain: string

	namespace:   string
	datacenters: list.MinItems(1)
	type:        "service"

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
			port: registration: {}
		}

		count: 1

		volume: "persist": {
			type:      "host"
			read_only: false
			source:    "\(namespace)-\(#dbSyncNetwork)"
		}

		service: "\(namespace)-snapshot-\(#dbSyncNetwork)": {
			address_mode: "host"
			port:         "snapshot"
			task:         "snapshot"
			tags: [
				"ingress",
				"snapshot",
				#dbSyncNetwork,
				namespace,
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-snapshot-\(#dbSyncNetwork).rule=Host(`\(#snapshotDomain)`)",
				"traefik.http.routers.\(namespace)-snapshot-\(#dbSyncNetwork).entrypoints=https",
				"traefik.http.routers.\(namespace)-snapshot-\(#dbSyncNetwork).tls=true",
			]
		}

		service: "\(namespace)-registration-\(#dbSyncNetwork)": {
			address_mode: "host"
			port:         "registration"
			task:         "registration"
			tags: [
				"ingress",
				"registration",
				#dbSyncNetwork,
				namespace,
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-registration-\(#dbSyncNetwork).rule=Host(`\(#registrationDomain)`)",
				"traefik.http.routers.\(namespace)-registration-\(#dbSyncNetwork).entrypoints=https",
				"traefik.http.routers.\(namespace)-registration-\(#dbSyncNetwork).tls=true",
			]
		}

		let ref = {
			dbSyncRev:     #dbSyncRev
			dbSyncNetwork: #dbSyncNetwork
		}

		task: "db-sync": tasks.#DbSync & {
			#dbSyncRev:     ref.dbSyncRev
			#dbSyncNetwork: ref.dbSyncNetwork
		}

		task: "postgres": tasks.#Postgres & {
			#dbSyncRev: ref.dbSyncRev
		}

		task: "cardano-node": tasks.#CardanoNode & {
			#dbSyncNetwork: ref.dbSyncNetwork
		}

		task: "snapshot": tasks.#Snapshot & {
			#dbSyncNetwork: ref.dbSyncNetwork
			#namespace:     namespace
		}

		task: "registration": tasks.#Registration & {
			#dbSyncNetwork: ref.dbSyncNetwork
			#namespace:     namespace
		}

		task: "promtail": tasks.#Promtail
	}
}
