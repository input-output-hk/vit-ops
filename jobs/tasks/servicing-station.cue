package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

#ServicingStation: types.#stanza.task & {
	#domain: string
	#block0: {url: string, checksum: string}
	#database: {url: string, checksum: string}
	#flake: types.#flake
	#version: string

	driver: "exec"

	config: {
		flake:   #flake
		command: "/bin/vit-servicing-station-server"
		args: ["--in-settings-file", "local/station-config.json"]
	}

	env: {
		PATH: "/bin"
		SERVICE_VERSION: #version
	}

	resources: {
		cpu:    100
		memory: 512
	}

	template: "local/station-config.json": {
		data: """
			{
			  "tls": {
			    "cert_file": null,
			    "priv_key_file": null
			  },
			  "cors": {
			    "allowed_origins": [ "https://\(#domain)", "http://127.0.0.1" ],
			    "max_age_secs": null
			  },
			  "db_url": "local/database.sqlite3/database.sqlite3",
			  "block0_path": "local/block0.bin/block0.bin",
			  "enable_api_tokens": false,
			  "log": {
			    "log_level": "debug"
			  },
			  "address": "0.0.0.0:{{ env "NOMAD_PORT_web" }}"
			  "version": ""
			}
			"""
	}

	artifact: "local/block0.bin": {
		source: #block0.url
		options: {
			checksum: #block0.checksum
		}
	}

	artifact: "local/database.sqlite3": {
		source: #database.url
		options: {
			checksum: #database.checksum
		}
	}
}
