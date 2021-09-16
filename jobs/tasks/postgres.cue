package tasks

import "github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"

#Postgres: types.#stanza.task & {
	#dbSyncRev:     types.#gitRevision
	#postgresFlake: string

	driver: "exec"

	resources: {
		cpu:    2500
		memory: 1024
	}

	kill_timeout: "60s"

	volume_mount: "persist": {
		destination: "/persist"
	}

	config: {
		flake: [
			"github:NixOS/nixpkgs/nixos-21.05#bashInteractive",
			"github:NixOS/nixpkgs/nixos-21.05#postgresql_11",
			"github:NixOS/nixpkgs/nixos-21.05#coreutils",
			"github:NixOS/nixpkgs/nixos-21.05#cacert",
			"github:NixOS/nixpkgs/nixos-21.05#glibcLocales",
		]
		command: "/bin/bash"
		args: ["/local/entrypoint.sh"]
	}

	template: "local/entrypoint.sh": data: """
		set -exuo pipefail

		mkdir -p /run/postgresql
		mkdir -p "$PGDATA"
		chmod 0700 "$PGDATA"

		if [ ! -s "$PGDATA/PG_VERSION" ]; then
		  initdb
		fi

		ln -sfn "/local/postgresql.conf" "$PGDATA/postgresql.conf"

		(
		  until pg_isready --timeout 30 --host /alloc; do sleep 1; done
		  createuser --username nobody --host /alloc --createdb --superuser cexplorer
		) &

		exec postgres "$@"
		"""

	template: "local/pg_hba.conf": data: """
		local all all trust
		"""

	template: "local/pg_ident.conf": data: " "

	template: "local/postgresql.conf": data: """
		hba_file = '/local/pg_hba.conf'
		ident_file = '/local/pg_ident.conf'
		log_destination = 'stderr'
		log_line_prefix = '[%p] '
		unix_socket_directories = '/alloc'
		listen_addresses = ''
		max_locks_per_transaction = 1024
		"""

	env: {
		PGDATA:         "/persist/postgres"
		PATH:           "/bin"
		LOCALE_ARCHIVE: "/current-alloc/lib/locale/locale-archive"
	}
}
