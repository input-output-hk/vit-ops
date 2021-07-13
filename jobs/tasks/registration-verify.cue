package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#RegistrationVerify: types.#stanza.task & {
	#dbSyncNetwork: string
	#namespace:     string
	#domain:        string

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	kill_signal: "SIGINT"

	resources: {
		cpu:    1500
		memory: 2 * 1024
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake:   "github:input-output-hk/vit-testing/5d7f68d5680bd723a7498f74b9e2cd64b8bd9859#registration-verify-service"
		command: "/bin/registration-service"
		args: ["--config", "/secrets/registration.config"]
	}

	env: {
		CARDANO_NODE_SOCKET_PATH: "/alloc/node.socket"
	}

	template: "secrets/registration.config": {
		change_mode:       "noop"
		_snapshot_address: string
		_snapshot_token:   string
		if #dbSyncNetwork == "mainnet" {
			_snapshot_address: "https://snapshot-\(#dbSyncNetwork).\(#domain)"
			_snapshot_token:   "{{with secret \"kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/snapshot\"}}{{.Data.data.token}}{{end}}"
		}
		if #dbSyncNetwork == "testnet" {
			_snapshot_address: "https://snapshot-\(#dbSyncNetwork).\(#domain)"
			_snapshot_token:   "{{with secret \"kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/snapshot\"}}{{.Data.data.token}}{{end}}"
		}
		data: """
		{
		  "port": {{ env "NOMAD_PORT_registration_verify" }},
		  "jcli": "jcli",
		  "result-dir": "/persist/registration",
		  "cardano-cli": "cardano-cli",
		  "voter-registration": "voter-registration",
		  "vit-kedqr": "vit-kedqr",
		  "network": "\(_snapshot_address)",
		  "token": "\(_snapshot_token)"
		}
		"""
	}
}
