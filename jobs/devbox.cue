package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#DevBox: types.#stanza.job & {
	#flakes: [string]: types.#flake
	#cardanoNodeFlake: string

	type: "service"

	group: devbox: {
		task: "devbox": tasks.#Devbox & {
			#flake: #flakes.devBox
		}

		let ref = {
			cardanoNodeFlake: #cardanoNodeFlake
		}

		task: "cardano-node": tasks.#CardanoNode & {
			#dbSyncNetwork:    "testnet"
			#cardanoNodeFlake: ref.cardanoNodeFlake
		}
	}
}
