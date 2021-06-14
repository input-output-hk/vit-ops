package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#Wormhole: types.#stanza.job & {
	type: "batch"

	namespace: string

	group: wormhole: {
		volume: "persist": {
			type:      "host"
			read_only: false
			source:    namespace
		}

		task: wormhole: tasks.#Wormhole
	}
}
