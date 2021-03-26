package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#JormungandrMonitor: types.#stanza.task & {
	driver: "exec"

	resources: {
		cpu:    100
		memory: 256
	}

	config: {
		flake:   "github:input-output-hk/vit-ops?rev=c9251b4f3f0b34a22e3968bf28d5a049da120f8f#jormungandr-monitor-entrypoint"
		command: "/bin/entrypoint"
		args: ["-config", "local/telegraf.config"]
	}

	env: {
		SLEEP_TIME: "10"
	}

	template: "local/env.txt": {
		env:         true
		change_mode: "restart"
		data: """
			PORT="{{ env "NOMAD_PORT_prometheus" }}"
			JORMUNGANDR_API="http://{{ env "NOMAD_ADDR_rest" }}/api"
			"""
	}
}
