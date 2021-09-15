package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#DbSync: types.#stanza.job & {
	_hex:                      "[0-9a-f]"
	#dbSyncNetwork:            "testnet" | "mainnet"
	#dbSyncRev:                =~"^\(_hex){40}$"
	#vitOpsRev:                string
	#dbSyncInstance:           =~"^i-\(_hex){17}$"
	#dbSyncFlake:              string
	#postgresFlake:            string
	#cardanoNodeFlake:         string
	#snapshotDomain:           string
	#registrationDomain:       string
	#registrationVerifyDomain: string

	namespace: string
	type:      "service"

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
			port: registration_verify: {}
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

		service: "\(namespace)-registration-verify-\(#dbSyncNetwork)": {
			address_mode: "host"
			port:         "registration_verify"
			task:         "registration-verify"
			tags: [
				"ingress",
				"registration-verify",
				#dbSyncNetwork,
				namespace,
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-registration-verify-\(#dbSyncNetwork).rule=Host(`\(#registrationVerifyDomain)`)",
				"traefik.http.routers.\(namespace)-registration-verify-\(#dbSyncNetwork).entrypoints=https",
				"traefik.http.routers.\(namespace)-registration-verify-\(#dbSyncNetwork).tls=true",
			]
		}

		let ref = {
			dbSyncRev:        #dbSyncRev
			dbSyncNetwork:    #dbSyncNetwork
			dbSyncFlake:      #dbSyncFlake
			postgresFlake:    #postgresFlake
			cardanoNodeFlake: #cardanoNodeFlake
		}

		task: "db-sync": tasks.#DbSync & {
			#dbSyncRev:     ref.dbSyncRev
			#dbSyncNetwork: ref.dbSyncNetwork
			#dbSyncFlake:   ref.dbSyncFlake
		}

		task: "postgres": tasks.#Postgres & {
			#dbSyncRev:     ref.dbSyncRev
			#postgresFlake: ref.postgresFlake
		}

		task: "cardano-node": tasks.#CardanoNode & {
			#dbSyncNetwork:    ref.dbSyncNetwork
			#cardanoNodeFlake: ref.cardanoNodeFlake
		}

		task: "snapshot": tasks.#Snapshot & {
			#dbSyncNetwork: ref.dbSyncNetwork
			#namespace:     namespace
		}

		task: "registration": tasks.#Registration & {
			#dbSyncNetwork: ref.dbSyncNetwork
			#namespace:     namespace
		}

		task: "registration-verify": tasks.#RegistrationVerify & {
			#dbSyncNetwork: ref.dbSyncNetwork
			#namespace:     namespace
			#domain:        ref.registrationVerifyDomain
		}

		task: "promtail": tasks.#Promtail
	}
}
