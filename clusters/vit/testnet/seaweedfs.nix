{ config, lib, ... }:
let cores = [ "core-1" "core-2" "core-3" ];
in {
  # services.cockroachdb = {
  #   enable = true;
  #   insecure = true;
  #   listen.address = "0.0.0.0";
  #   join = lib.concatStringsSep "," (lib.forEach cores (core:
  #     "${config.cluster.instances.${core}.privateIP}:${
  #       toString config.services.cockroachdb.listen.port
  #     }"));
  # };

# seaweed+ 10911  weed -v 4 filer -port 8888 -ip 172.16.2.10 -ip.bind 172.16.2.10 -master 172.16.0.10:9333,172.16.1.10:9333 -s3.port 8333
# 
# seaweed+  3775  weed -v 4 volume -port 8080 -dir /var/lib/seaweedfs-volume -metricsPort 9334 -minFreeSpacePercent 1 -dataCenter eu-central-1 -max 0 -mserver 172.16.0.10:9333,172.16.1.10:9333 -ip 172.16.2.10 -ip.bind 172.16.2.10
# 
# seaweed+  9697  weed -v 3 master -port 9333 -mdir /var/lib/seaweedfs-master -peers 172.16.0.10:9333,172.16.1.10:9333 -ip 172.16.2.10 -ip.bind 172.16.2.10 -volumeSizeLimitMB 1000 -volumePreallocate

  services.seaweedfs.filer = {
    enable = true;

    master = lib.forEach cores (core:
      "${config.cluster.instances.${core}.privateIP}:${
        toString config.services.seaweedfs.master.port
      }");

    peers = lib.forEach ["core-3"] (core:
      "${config.cluster.instances.${core}.privateIP}:${
        toString config.services.seaweedfs.filer.http.port
      }");

    # TODO: make consul service so we know where it's running.
    postgres.hostname = "${config.cluster.instances.core-1.privateIP}";
    postgres.port = 26257;
  };

  services.seaweedfs.mount = {
    enable = true;
    mounts = {
      # nomad-vit-testnet = "vit-testnet";
      "nomad-vit-store" = "vit-store";
    };
  };
}
