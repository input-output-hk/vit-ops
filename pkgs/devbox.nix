{ runCommand, writeShellScriptBin, lib, symlinkJoin, bashInteractive, cargo
, coreutils, curl, diffutils, fd, findutils, gitFull, gnugrep
, gnused, htop, jormungandr, jq, lsof, netcat, procps, remarshal, restic
, ripgrep, rust-analyzer, rustc, sqlite-interactive, strace, tcpdump, tmux, tree
, utillinux, vim, nodePkgs, ... }:
let
  entrypoint = writeShellScriptBin "entrypoint" ''
    echo "devbox is ready... you can connect using nomad exec"
    while true; do
      sleep 600
    done
  '';
in symlinkJoin {
  name = "entrypoint";
  paths = [
    bashInteractive
    nodePkgs.cardano-cli
    cargo
    coreutils
    curl
    diffutils
    entrypoint
    fd
    findutils
    gitFull
    gnugrep
    gnused
    htop
    jormungandr
    jq
    lsof
    netcat
    procps
    remarshal
    restic
    ripgrep
    rust-analyzer
    rustc
    sqlite-interactive
    strace
    tcpdump
    tmux
    tree
    utillinux
    vim
  ];
}

