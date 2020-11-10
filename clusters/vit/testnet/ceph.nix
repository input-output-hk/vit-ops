{ config, lib, ... }:
let cores = [ "core-1" "core-2" "core-3" ];
in {
  services.ceph = {
    enable = true;
    global = {
      clusterName = "vit-ceph";
      #clusterNetwork = "CIDR/netmask";
      fsid = "3d50a6cf-7176-48df-a495-0dda527634ff";   # Generated manually
      # TODO Can monHost & monInitialMembers be done better?
      monHost = "
        ${config.cluster.instances.core-1.privateIP},
        ${config.cluster.instances.core-2.privateIP},
        ${config.cluster.instances.core-3.privateIP}\n
      ";
      monInitialMembers = "
        ${config.cluster.instances.core-1.privateIP},
        ${config.cluster.instances.core-2.privateIP},
        ${config.cluster.instances.core-3.privateIP}\n
      ";
      #publicNetwork = "Insert CIDR/netmask for public network here";
    };

    mds = { enable = true; };   # MetaData Service
    mgr = { enable = true; };   # Manager daemon
    mon = { enable = true; };   # Monitor daemon
    osd = { enable = true; };   # Object Storage Daemon
    rgw = { enable = true; };   # RADOS Gateway daemon
  };
}
