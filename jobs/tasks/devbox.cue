package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#Devbox: types.#stanza.task & {
	#flake: types.#flake

	driver: "exec"

	resources: {
		cpu:    12000
		memory: 4000
	}

	config: {
		flake:   #flake
		command: "/bin/entrypoint"
	}

	env: {
		PATH: "/bin"
	}
}
