let
  sources = import ./nix/sources.nix { };
  pkgs = import sources.nixpkgs { };
  repl = import ../repl.nix;

  cardanolib-py = (import (sources.cardano-node + "/nix") {
    gitrev = sources.cardano-node.rev;
  }).cardanolib-py;
  cardano-node-nix =
    import (sources.cardano-node) { gitrev = sources.cardano-node.rev; };
  bech32 = cardano-node-nix.bech32;
  cardano-cli = cardano-node-nix.cardano-cli;
  vit-kedqr = import sources.vit-kedqr { };
  jorvit = import sources.jorvit { };
in pkgs.stdenv.mkDerivation {
  name = "vit-meta-shell";
  buildInputs = [
    repl.legacyPackages.x86_64-linux.jormungandr
    cardano-cli
    bech32
    pkgs.python3Packages.ipython
    pkgs.python3Packages.cbor2
    pkgs.python3Packages.docopt
    pkgs.python3Packages.psycopg2
    pkgs.python3Packages.cryptography
    pkgs.python3Packages.opencv4

    cardanolib-py
    vit-kedqr
    jorvit
    repl.legacyPackages.x86_64-linux.textql
    repl.legacyPackages.x86_64-linux.vit-servicing-station
  ];
  shellHook = ''
    source <(cardano-cli --bash-completion-script cardano-cli)
  '';
}
