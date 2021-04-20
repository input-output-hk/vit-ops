package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#Postgres: types.#stanza.task & {
	#dbSyncRev: types.#gitRevision

	driver: "exec"

	resources: {
		cpu:    13600
		memory: 512
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
