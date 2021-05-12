package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#DbSync: types.#stanza.task & {
	#dbSyncRev:     types.#gitRevision
	#dbSyncNetwork: string
	driver:         "exec"

	resources: {
		cpu:    2500
		memory: 1024 * 10
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
