{ pkgs, lib, ... }: {
  fileSystems."/mnt/gv1" = {
    device = "glusterd.service.consul:/gv1";
    fsType = "glusterfs";
  };

  systemd.services.consul.serviceConfig.ExecStartPost =
    let
      post = pkgs.writeShellScriptBin
        "consul-restart-gluster"
        ''
          ${pkgs.systemd}/bin/systemctl restart 'mnt-gv*.mount'
        '';

    in
    lib.mkBefore [
      "!${post}/bin/consul-restart-gluster"
    ];

  services.zfs = {
    autoSnapshot = {
      enable = true;
      monthly = lib.mkForce 0;
      hourly = 0;
      frequent = 0;
      daily = 2;
    };
  };

  # Change behaviour to only take snapshots of /var because everything else is irrelevant
  systemd.services.zfs-snapshot-enable = lib.mkForce {
    script = ''
      set -euo pipefail
      echo "The current state of zfs autosnapshots is:"
      zfs get com.sun:auto-snapshot
      echo " "
      zfs set com.sun:auto-snapshot=false tank
      zfs set com.sun:auto-snapshot=true tank/var
      echo "The new state of zfs autosnapshots is:"
      zfs get com.sun:auto-snapshot
      echo " "
      echo "The current size of existing zfs snapshots is:"
      zfs list -o space -t filesystem,snapshot
      echo " "
    '';
  };
}
