package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#Wormhole: types.#stanza.task & {
	driver: "exec"

	volume_mount: "persist": {
		destination: "/persist"
	}

	resources: {
		cpu:    100
		memory: 1024
	}

	config: {
		flake:   "github:input-output-hk/vit-ops#magic-wormhole"
		command: "/bin/wormhole"
		args: ["send", "/persist/fragments"]
	}
}
