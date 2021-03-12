package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"list"
)

#DevBox: types.#stanza.job & {
	#vitOpsRev:  string
	namespace:   string
	datacenters: list.MinItems(1)
	type:        "service"

	group: devbox: {
		task: "devbox": {
			driver: "exec"

			resources: {
				cpu:    12000
				memory: 4000
			}

			config: {
				flake:   "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#devbox-entrypoint"
				command: "/bin/entrypoint"
			}

			env: {
				PATH: "/bin"
			}
		}

		task: "cardano-node": {
			driver: "exec"

			resources: {
				cpu:    1000
				memory: 1024
			}

			config: {
				flake:   "github:input-output-hk/cardano-node?rev=14229feb119cc3431515dde909a07bbf214f5e26#cardano-node-testnet-debug"
				command: "/bin/cardano-node-entrypoint"
			}

			env: {
				PATH: "/bin"
			}
		}
	}
}
