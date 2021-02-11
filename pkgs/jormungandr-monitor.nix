{ lib, symlinkJoin, jormungandr-monitor, writeShellScriptBin, debugUtils, cacert
, coreutils, bashInteractive, busybox, curl, lsof }:
let
  PATH = lib.makeBinPath [ coreutils bashInteractive busybox curl lsof ];

  entrypoint = writeShellScriptBin "entrypoint" ''
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export PATH="${PATH}"

    ulimit -n 1024

    exec ${jormungandr-monitor} "$@"
  '';
in symlinkJoin {
  name = "entrypoint";
  paths = debugUtils ++ [ entrypoint ];
}
