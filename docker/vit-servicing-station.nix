{ buildLayeredImage, vit-servicing-station, pkgs, lib }:
let
  launcher = pkgs.writeShellScript "docker-executables" ''
    echo "${vit-servicing-station}/bin/vit-servicing-station-server" "$@"
    exec "${vit-servicing-station}/bin/vit-servicing-station-server" "$@"
  '';
in {
  vit-servicing-station = buildLayeredImage {
    name = "docker.vit.iohk.io/vit-servicing-station";
    contents = with pkgs; [
      bashInteractive
      coreutils
      curl
      fd
      findutils
      gnugrep
      gnused
      htop
      lsof
      netcat
      procps
      ripgrep
      sqlite-interactive
      tcpdump
      tmux
      tree
      utillinux
      vim
    ];
    config.Entrypoint = [ "${launcher}" ];
  };
}
