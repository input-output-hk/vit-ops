{ runCommand, writeShellScriptBin, lib, symlinkJoin, bashInteractive, cargo
, cargoc, coreutils, curl, diffutils, entrypoint, fd, findutils, gitFull
, gnugrep, gnused, htop, jormungandr, jq, lsof, netcat, procps, remarshal
, restic, ripgrep, rust-analyzer, rustc, sqlite-interactive, strace, tcpdump
, tmux, tree, utillinux, vim, ... }:
let
  entrypoint = writeShellScriptBin "entrypoint" ''
    echo "devbox is ready... you can connect using nomad exec"
    while true;
      sleep 600
    done
  '';
in symlinkJoin {
  name = "entrypoint";
  paths = [
    bashInteractive
    cargo
    cargoc
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

