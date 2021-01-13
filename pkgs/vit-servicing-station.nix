{ runCommand, symlinkJoin, debugUtils, fetchurl, ... }:
let
  version = "0.1.0";
  vit-servicing-station = runCommand "vit-servicing-station-static" {
    src = fetchurl {
      url =
        "https://github.com/input-output-hk/vit-servicing-station/releases/download/v${version}/vit-servicing-station-${version}-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "sha256-esVtO4GzQob7Xev1RzaBq7SU1u4noCml2lAfghRJuHg=";
    };
  } ''
    mkdir -pv $out/bin
    tar -xvf $src -C $out/bin/
  '';
in symlinkJoin {
  name = "vit-servicing-station-env";
  paths = debugUtils ++ [ vit-servicing-station ];
}
