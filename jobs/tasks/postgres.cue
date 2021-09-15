package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#Postgres: types.#stanza.task & {
	#dbSyncRev:     types.#gitRevision
	#postgresFlake: string

	driver: "exec"

	resources: {
		cpu:    2500
		memory: 1024
	}

	kill_timeout: "60s"

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake:   #postgresFlake
		command: "/bin/postgres-entrypoint"
	}

	env: {
		PGDATA: "/persist/postgres"
		PATH:   "/bin"
	}
}
