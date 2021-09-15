package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#CardanoNode: types.#stanza.task & {
	#dbSyncNetwork:    string
	#cardanoNodeFlake: string

	driver: "exec"

	resources: {
		cpu:    3600
		memory: 1024 * 10
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake:   #cardanoNodeFlake
		command: "/bin/cardano-db-sync-\(#dbSyncNetwork)"
	}

	env: {
		PATH: "/bin"
	}
}
