package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#Postgres: types.#stanza.task & {
	#dbSyncRev: types.#gitRevision

	driver: "exec"

	resources: {
		cpu:    2500
		memory: 1024
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
