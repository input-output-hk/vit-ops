{ config, self, lib, ... }: {
  imports = [ (self.inputs.bitte + /profiles/glusterfs/client.nix) ];

  services.nomad.client = {
    chroot_env = {
      "/etc/passwd" = "/etc/passwd";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/services" = "/etc/services";
    };

    host_volume = [{
      catalyst-fund4 = {
        path = "/mnt/gv0/nomad/catalyst-fund4";
        read_only = false;
      };

      catalyst-sync = {
        path = "/mnt/gv0/nomad/catalyst-sync";
        read_only = false;
      };

      catalyst-sync-testnet = {
        path = "/mnt/gv0/nomad/catalyst-sync-testnet";
        read_only = false;
      };

      catalyst-sync-mainnet = {
        path = "/mnt/gv0/nomad/catalyst-sync-mainnet";
        read_only = false;
      };
    }];
  };

  system.activationScripts.nomad-host-volumes-new =
    lib.pipe config.services.nomad.client.host_volume [
      (map builtins.attrNames)
      builtins.concatLists
      (map (d: ''
        mkdir -p /mnt/gv0/nomad/${d}
        chown -R nobody:nogroup /mnt/gv0/nomad/${d}
      ''))
      (builtins.concatStringsSep "\n")
    ];
}
