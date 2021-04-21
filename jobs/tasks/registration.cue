package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#Registration: types.#stanza.task & {
	#dbSyncNetwork: string
	#namespace:     string

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	resources: {
		cpu:    6800
		memory: 2 * 1024
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake:   "github:input-output-hk/vit-testing/a9f26829cab92231736c1b4648799a73e76da993#registration-service"
		command: "/bin/registration-service"
		args: ["--config", "/secrets/registration.config"]
	}

	template: "secrets/registration.config": {
		change_mode: "noop"
		_magic:      string
		if #dbSyncNetwork == "mainnet" {
			_magic: "\"mainnet\""
		}
		if #dbSyncNetwork == "testnet" {
			_magic: "{ \"testnet\": 1097911063 }"
		}
		data: """
		{
		  "port": {{ env "NOMAD_PORT_registration" }},
		  "jcli": "jcli.exe",
		  "result-dir": "/persist/registration",
		  "cardano-cli": "cardano-cli",
		  "voter-registration": "voter-registration",
		  "vit-kedqr": "vit-kedqr",
		  "network": \(_magic),
		  "token": "{{with secret "kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/registration"}}{{.Data.data.token}}{{end}}"
		}
		"""
	}
}
