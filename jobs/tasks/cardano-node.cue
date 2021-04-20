package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#CardanoNode: types.#stanza.task & {
	#dbSyncNetwork: string

	driver: "exec"

	resources: {
		cpu:    3000
		memory: 1024 * 6
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
