package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#Telegraf: types.#stanza.task & {
	#prometheusPort: string
	#clientId:       string | *"{{ env \"NOMAD_JOB_NAME\" }}-{{ env \"NOMAD_ALLOC_INDEX\" }}"

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    100
		memory: 128
	}

	config: {
		flake:   "github:NixOS/nixpkgs/nixos-21.05#telegraf"
		command: "/bin/telegraf"
		args: ["-config", "/local/telegraf.config"]
	}

	template: "local/telegraf.config": {
		data: """
		[agent]
		flush_interval = "10s"
		interval = "10s"
		omit_hostname = false

		[global_tags]
		client_id = "\(#clientId)"
		namespace = "{{ env "NOMAD_NAMESPACE" }}"

		[inputs.prometheus]
		metric_version = 1

		urls = [ "http://{{ env "NOMAD_ADDR_\(#prometheusPort)" }}" ]

		[outputs.influxdb]
		database = "telegraf"
		urls = [ "http://172.16.0.20:8428" ]
		"""
	}
}
