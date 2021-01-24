let
  sources = import ./nix/sources.nix { };
  pkgs = import sources.nixpkgs { };
  vit-pkgs = import ../default.nix { };

  src = pkgs.fetchurl {
    url =
      "https://github.com/input-output-hk/jormungandr/releases/download/v0.10.0-alpha.2/jormungandr-0.10.0-alpha.2-x86_64-unknown-linux-musl-generic.tar.gz";
    sha256 = "sha256-WmlQuY/FvbFR3ba38oh497XmCtftjsrHu9bfKsubqi0=";
  };
  jormungandr =
    pkgs.runCommand "jormungandr" { buildInputs = [ pkgs.gnutar ]; } ''
      mkdir -p $out/bin
      cd $out/bin
      tar -zxvf ${src}
    '';
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
    jormungandr
    cardano-cli
    bech32
    pkgs.python3Packages.black
    pkgs.python3Packages.ipython
    pkgs.python3Packages.cbor2
    pkgs.python3Packages.docopt
    pkgs.python3Packages.psycopg2
    pkgs.python3Packages.cryptography
    pkgs.python3Packages.opencv4

    cardanolib-py
    vit-kedqr
    jorvit
    vit-pkgs.defaultNix.legacyPackages.x86_64-linux.vit-servicing-station
  ];
  shellHook = ''
    export CARDANO_NODE_SOCKET_PATH=/home/sam/work/iohk/cardano-node/master/state-node-testnet/node.socket
    source <(cardano-cli --bash-completion-script cardano-cli)
  '';
}
