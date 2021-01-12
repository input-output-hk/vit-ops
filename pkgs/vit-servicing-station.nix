{ runCommand, symlinkJoin, debugUtils, fetchurl, ... }: let
  vit-servicing-station = runCommand "vit-servicing-station-static" {
    src = fetchurl {
      url =
        "https://github.com/mzabaluev/vit-servicing-station/releases/download/v0.1.0-ci-test.1/vit-servicing-station-0.1.0-ci-test.1-x86_64-unknown-linux-musl.tar.gz";
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
