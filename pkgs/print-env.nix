{ writeShellScriptBin, symlinkJoin, debugUtils, ... }:
let
  entrypoint = writeShellScriptBin "print-env" ''
    env

    while true; do
      sleep 1
    done
  '';
in symlinkJoin {
  name = "entrypoint";
  paths = debugUtils ++ [ entrypoint ];
}
