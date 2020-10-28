{ ... }: {
  services.nomad.client = {
    host_volume = [{
      vit-testnet = {
        path = "/var/lib/seaweedfs-mount/nomad/vit-testnet";
        read_only = false;
      };
    }];
  };
}
