package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#DbSync: types.#stanza.task & {
	#dbSyncRev:     types.#gitRevision
	#dbSyncNetwork: string
	#dbSyncFlake:   string

	driver: "exec"

	resources: {
		cpu:    3600
		memory: 1024 * 24
	}

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake: [
			#dbSyncFlake,
			"github:NixOS/nixpkgs#bashInteractive",
			"github:NixOS/nixpkgs#cacert",
			"github:NixOS/nixpkgs#coreutils",
			"github:NixOS/nixpkgs#curl",
			"github:NixOS/nixpkgs#findutils",
			"github:NixOS/nixpkgs#gnutar",
			"github:NixOS/nixpkgs#glibcLocales",
			"github:NixOS/nixpkgs#gzip",
			"github:NixOS/nixpkgs#iana-etc",
			"github:NixOS/nixpkgs#iproute",
			"github:NixOS/nixpkgs#iputils",
			"github:NixOS/nixpkgs#libidn",
			"github:NixOS/nixpkgs#libpqxx",
			"github:NixOS/nixpkgs#postgresql",
			"github:NixOS/nixpkgs#socat",
		]
		command: "/bin/cardano-db-sync-\(#dbSyncNetwork)"
	}

	env: {
		CARDANO_NODE_SOCKET_PATH: "/alloc/node.socket"
		PATH:                     "/bin"
		SSL_CERT_FILE:            "/etc/ssl/certs/ca-bundle.crt"
	}
}
