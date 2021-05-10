package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#Wormhole: types.#stanza.job & {
	type: "batch"

	group: wormhole: {
		volume: "persist": {
			type:      "host"
			read_only: false
			source:    "catalyst-dryrun"
		}

		task: wormhole: tasks.#Wormhole
	}
}
