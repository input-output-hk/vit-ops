{ ... }: {
  fileSystems."/mnt/gv1" = {
    device = "glusterd.service.consul:/gv1";
    fsType = "glusterfs";
  };
}
