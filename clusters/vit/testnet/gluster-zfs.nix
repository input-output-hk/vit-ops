{ nodeName, config, pkgs, ... }:
let
  # with 3 storage nodes, and redundancy at 1, we have 2/3 of size*3. We only
  # want to use 90% to ensure the quota is actually applied in time, so ew set
  # it to 2*0.9 = 1.8.
  quotaSize =
    config.tf.core.configuration.resource.aws_ebs_volume."${nodeName}-zfs".size
    * 1.8;
in {
  fileSystems = {
    "/data/brick2" = {
      label = "brick2";
      device = "/dev/nvme2n1";
      fsType = "xfs";
      formatOptions = "-i size=512";
      autoFormat = true;
    };

    "/mnt/gv1" = {
      device = "${nodeName}:/gv1";
      fsType = "glusterfs";
    };
  };

  systemd.services."mnt-gv1.mount" = {
    after = [ "setup-glusterfs.service" ];
    wants = [ "setup-glusterfs.service" ];
  };

  systemd.services.setup-glusterfs-zfs = {
    wantedBy = [ "multi-user.target" ];
    after = [ "setup-glusterfs.service" "glusterfs.service" ];
    path = with pkgs; [ glusterfs gnugrep xfsprogs utillinux jq ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "20s";
      ExecStart = pkgs.writeBashChecked "setup-glusterfs.sh" ''
        set -exuo pipefail

        xfs_growfs /data/brick2

        mkdir -p /data/brick2/gv1
        if ! gluster volume info 2>&1 | grep 'Volume Name: gv1'; then
          gluster volume create gv1 \
            disperse 3 \
            redundancy 1 \
            storage-0:/data/brick2/gv1 \
            storage-1:/data/brick2/gv1 \
            storage-2:/data/brick2/gv1 \
            force
        fi

        gluster volume start gv1 force

        gluster volume bitrot gv1 enable || true
        gluster volume quota gv1 enable || true
        gluster volume quota gv1 limit-usage / ${toString quotaSize}GB
      '';
    };
  };
}
