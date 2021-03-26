package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#Snapshot: types.#stanza.task & {
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
		flake:   "github:input-output-hk/vit-testing/9dbb1c283372eb8e9cad9806a5b9b76f8077fb62#snapshot-trigger-service"
		command: "/bin/snapshot-trigger-service"
		args: ["--config", "/secrets/snapshot.config"]
	}

	template: "genesis-template.json": data: "{}"

	template: "secrets/snapshot.config": {
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
		  "port": {{ env "NOMAD_PORT_snapshot" }},
		  "result-dir": "/persist/snapshot",
		  "voting-tools": {
		    "bin": "voting-tools",
		    "network": \(_magic),
		    "db": "cexplorer",
		    "db-user": "cexplorer",
		    "db-host": "/alloc",
		    "scale": 1000000
		  },
		  "token": "{{with secret "kv/data/nomad-cluster/\(#namespace)/\(#dbSyncNetwork)/snapshot"}}{{.Data.data.token}}{{end}}"
		}
		"""
	}
}
