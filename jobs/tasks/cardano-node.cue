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
		if #dbSyncNetwork == "mainnet" {
			memory: 1024 * 16
		}
		if #dbSyncNetwork == "testnet" {
			memory: 1024 * 10
		}
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake:   #cardanoNodeFlake
		command: "/bin/cardano-node-\(#dbSyncNetwork)"
	}

	env: {
		PATH: "/bin"
	}
}
