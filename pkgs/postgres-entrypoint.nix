{ lib, symlinkJoin, writeShellScriptBin, writeText, glibcLocales, coreutils
, postgresql, bashInteractive, ... }:
let
  deps = [ coreutils postgresql bashInteractive ];

  configs = rec {
    hba = writeText "pg_hba.conf" ''
      local all all trust
    '';
    ident = writeText "pg_ident.conf" "";
    postgres = writeText "postgresql.conf" ''
      hba_file = '${hba}'
      ident_file = '${ident}'
      log_destination = 'stderr'
      log_line_prefix = '[%p] '
      unix_socket_directories = '/alloc'
      listen_addresses = '''
      max_locks_per_transaction = 1024
    '';
  };

  PATH = lib.makeBinPath deps;

  entrypoint = writeShellScriptBin "postgres-entrypoint" ''
    set -exuo pipefail

    export PATH="${PATH}"
    export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive

    mkdir -p /run/postgresql
    mkdir -p "$PGDATA"
    chmod 0700 "$PGDATA"

    if [ ! -s "$PGDATA/PG_VERSION" ]; then
      initdb
    fi

    ln -sfn "${configs.postgres}" "$PGDATA/postgresql.conf"

    (
      pg_isready -t 30
      createuser --createdb --superuser cexplorer
    ) &

    exec postgres "$@"
  '';
in symlinkJoin {
  name = "postgres-entrypoint";
  paths = [ entrypoint ] ++ deps;
}
