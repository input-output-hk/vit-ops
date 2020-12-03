{ stdenv, removeReferencesTo, crystal, makeWrapper, openssl, restic, remarshal
, jormungandr }:
let
  inner = crystal.buildCrystalPackage {
    pname = "restic-backup";
    version = "0.0.1";
    format = "crystal";

    src = ./.;

    buildInputs = [ openssl ];

    crystalBinaries.restic-backup = {
      src = "./restic-backup.cr";
      options = [ "--verbose" "--release" ];
    };
  };

  PATH = stdenv.lib.makeBinPath [ jormungandr restic remarshal ];

in stdenv.mkDerivation {
  pname = inner.pname;
  version = inner.version;

  nativeBuildInputs = [ removeReferencesTo makeWrapper ];
  src = inner;

  installPhase = ''
    mkdir -p $out/bin
    cp $src/bin/restic-backup $out/bin/restic-backup
    remove-references-to -t ${crystal.lib} $out/bin/*
    wrapProgram $out/bin/restic-backup \
      --set PATH ${PATH}
  '';
}
