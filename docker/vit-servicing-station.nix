{ buildLayeredImage, vit-servicing-station, pkgs, lib, debugUtils }:
let
  launcher = pkgs.writeShellScript "docker-executables" ''
    echo "${vit-servicing-station}/bin/vit-servicing-station-server" "$@"
    exec "${vit-servicing-station}/bin/vit-servicing-station-server" "$@"
  '';
in {
  vit-servicing-station = buildLayeredImage {
    name = "docker.vit.iohk.io/vit-servicing-station";
    contents = with pkgs;
      [
        findutils
        gnused
        htop
        ripgrep
        sqlite-interactive
        tcpdump
        tmux
        utillinux
        vim
      ] ++ debugUtils;
    config.Entrypoint = [ "${launcher}" ];
  };
}
