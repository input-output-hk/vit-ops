package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#DbSync: types.#stanza.task & {
	#dbSyncRev:     types.#gitRevision
	#dbSyncNetwork: string
	#dbSyncFlake:   string

	driver: "exec"

	resources: {
		cpu:    3600
		memory: 1024 * 15
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake: [
			#dbSyncFlake,
			"github:NixOS/nixpkgs#bashInteractive",
		]
		command: "/bin/cardano-db-sync-\(#dbSyncNetwork)"
	}

	env: {
		CARDANO_NODE_SOCKET_PATH: "/alloc/node.socket"
		PATH:                     "/bin"
	}
}
