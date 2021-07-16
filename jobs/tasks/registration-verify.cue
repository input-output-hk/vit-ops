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
		flake:   "github:input-output-hk/vit-testing/32d849099791a014902d4ff7dd8eb192afd868d8#registration-verify-service"
		command: "/bin/registration-verify-service"
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
			_snapshot_address: "https://snapshot-\(#dbSyncNetwork).vit.iohk.io"
			_snapshot_token:   "{{with secret \"kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/snapshot\"}}{{.Data.data.token}}{{end}}"
		}
		if #dbSyncNetwork == "testnet" {
			_snapshot_address: "https://snapshot-\(#dbSyncNetwork).vit.iohk.io"
			_snapshot_token:   "{{with secret \"kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/snapshot\"}}{{.Data.data.token}}{{end}}"
		}
		data: """
		{
		  "port": {{ env "NOMAD_PORT_registration_verify" }},
		  "jcli": "jcli",
		  "network": "\(#dbSyncNetwork)",
		  "snapshot-address": "\(_snapshot_address)",
		  "initial-snapshot-job-id":"e1eee0fe-9962-4c3a-b0af-e627e5517b18",
		  "snapshot-token": "\(_snapshot_token)"
		}
		"""
	}
}
