{ pkgs, lib, config, ... }:
let
  volumes = {
    local = [ "catalyst-sync-mainnet" "catalyst-sync-testnet" ];
    gluster = builtins.attrNames config.services.nomad.namespaces;
  };
in {
  systemd.services.gluster-permissions = {
    before = [ "nomad.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -xu
      export PATH="${lib.makeBinPath (with pkgs; [ fd coreutils ])}:$PATH"
    '' + (lib.pipe volumes.gluster [
      (map (d: ''
        mkdir -p /mnt/gv0/nomad/${d}
        fd . -o root /mnt/gv0/nomad/${d} -X chown nobody:nogroup
      ''))
      (builtins.concatStringsSep "\n")
    ]);
  };

  systemd.timers.gluster-permissions = {
    description = "Regularly fix gluster permissions";
    before = [ "nomad.service" ];
    wantedBy = [ "multi-user.target" ];

    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = "true";
      Unit = "gluster-permissions.service";
    };
  };
}
