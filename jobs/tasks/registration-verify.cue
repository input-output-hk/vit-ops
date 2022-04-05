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
		flake:   "github:input-output-hk/vit-testing/86ab945e382eff6c2237947813f375c0f19b8a9f#registration-verify-service"
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
		  "snapshot-address": "\(_snapshot_address)",
		  "snapshot-token": "\(_snapshot_token)",
		  "network": "\(#dbSyncNetwork)"
		}
		"""
	}
}
