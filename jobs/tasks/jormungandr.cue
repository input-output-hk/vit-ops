package tasks

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"strconv"
)

#Jormungandr: types.#stanza.task & {
	#namespace:         string
	#role:              "leader" | "follower"
	#requiredPeerCount: uint
	#index:             uint
	#block0: {url: string, checksum: string}
	#flake: types.#flake

	driver: "exec"

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	kill_signal: "SIGINT"

	restart: {
		interval: "15m"
		attempts: 5
		delay:    "1m"
		mode:     "delay"
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	resources: {
		cpu:    3300
		memory: 4 * 1024
	}

	config: {
		flake:   #flake
		command: "/bin/entrypoint"
	}

	env: {
		PATH:      "/bin"
		NAMESPACE: #namespace
		// TODO: fix this silly thing
		if #role == "leader" {
			PRIVATE: "true"
		}
		if #role != "leader" {
			PRIVATE: ""
		}
		REQUIRED_PEER_COUNT: "0"
		RUST_BACKTRACE:      "full"
		STORAGE_DIR:         "/local/storage"
		AWS_DEFAULT_REGION:  "us-east-1"
	}

	template: "local/node-config.json": {
		change_mode: "noop"

		#mempool: string
		if #role == "follower" {
			#mempool: """
				"log_max_entries": 100000,
				"pool_max_entries": 100000,
				"persistent_log": {
				  "dir": "/persist/fragments"
				}
				"""
		}
		if #role != "follower" {
			#mempool: """
				"log_max_entries": 100000,
				"pool_max_entries": 100000
				"""
		}

		data: """
		{
		  "bootstrap_from_trusted_peers": true,
		  "explorer": {
		    "enabled": false
		  },
		  "leadership": {
		    "logs_capacity": 1024
		  },
		  "log": [
		    {
		      "format": "plain",
		      "level": "debug",
		      "output": "stdout"
		    }
		  ],
		  "mempool": {
		    \(#mempool)
		  },
		  "p2p": {
		    "allow_private_addresses": true,
		    "topics_of_interest": {
		        "blocks": "high",
		        "messages": "high"
		    },
		    "layers": {
		      "preferred_list": {
		        "peers": [
		          {{ range service "\(#namespace)-jormungandr-internal|any" }}
		            {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
		              {{ scratch.MapSet "vars" .ID . }}
		            {{ end }}
		          {{ end }}
		          {{ range $index, $service := (scratch.MapValues "vars" ) }}
		            {{- if ne $index 0}},{{else}} {{end -}}
		            { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
		          {{ end -}}
		        ],
		        "view_max": 20
		      }
		    },
		    "listen_address": "/ip4/0.0.0.0/tcp/{{ env "NOMAD_PORT_rpc" }}",
		    "max_bootstrap_attempts": 3,
		    "max_client_connections": 192,
		    "max_connections": 256,
		    "max_unreachable_nodes_to_connect_per_event": 20,
		    "policy": {
		      "quarantine_duration": "5s",
		      "quarantine_whitelist": [
		        {{ range service "\(#namespace)-jormungandr-internal|any" }}
		          {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
		            {{ scratch.MapSet "vars" .ID . }}
		          {{ end }}
		        {{ end }}
		        {{ range $index, $service := (scratch.MapValues "vars" ) }}
		          {{- if ne $index 0}},{{else}} {{end -}}
		          "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}"
		        {{ end -}}
		      ]
		    },
		    "public_address": "/ip4/{{ env "NOMAD_HOST_IP_rpc" }}/tcp/{{ env "NOMAD_HOST_PORT_rpc" }}",
		    "trusted_peers": [
		      {{ range service "\(#namespace)-jormungandr-internal|any" }}
		        {{ if (not (.ID | regexMatch (env "NOMAD_ALLOC_ID"))) }}
		          {{ scratch.MapSet "vars" .ID . }}
		        {{ end }}
		      {{ end }}
		      {{ range $index, $service := (scratch.MapValues "vars" ) }}
		        {{- if ne $index 0}},{{else}} {{end -}}
		        { "address": "/ip4/{{ .NodeAddress }}/tcp/{{ .Port }}" }
		      {{ end -}}
		    ]
		  },
		  "rest": {
		    "listen": "0.0.0.0:{{ env "NOMAD_PORT_rest" }}"
		  },
		  "skip_bootstrap": \(strconv.FormatBool(#requiredPeerCount == 0))
		}
		"""
	}

	template: "secrets/env.txt": {
		env:         true
		change_mode: "noop"
		data:        """
		AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
		AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
		RESTIC_PASSWORD="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.password}}{{end}}"
		RESTIC_REPOSITORY="s3:http://172.16.0.20:9000/restic"
		RESET="{{with secret "kv/data/nomad-cluster/\(#namespace)/reset"}}{{.Data.data.value}}{{end}}"
		"""
	}

	if #role == "leader" {
		template: "secrets/bft-secret.yaml": {
			data: """
			genesis:
			bft:
			  signing_key: {{with secret "kv/data/nomad-cluster/bft/\(#namespace)/\(#index)"}}{{.Data.data.value}}{{end}}
			"""
		}
	}

	artifact: "local/block0.bin": {
		source: #block0.url
		options: {
			checksum: #block0.checksum
		}
	}
}
