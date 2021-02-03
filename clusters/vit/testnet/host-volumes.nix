{ config, lib, ... }: {
  services.nomad.client = {
    chroot_env = {
      "/etc/passwd" = "/etc/passwd";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/services" = "/etc/services";
    };

    host_volume = [{
      catalyst-dryrun-db-sync = {
        path = "/var/lib/nomad-volumes/catalyst-dryrun-db-sync";
        read_only = false;
      };

      catalyst-fund3-db-sync = {
        path = "/var/lib/nomad-volumes/catalyst-fund3-db-sync";
        read_only = false;
      };
    }];
  };

  system.activationScripts.nomad-host-volumes =
    lib.pipe config.services.nomad.client.host_volume [
      (map builtins.attrNames)
      builtins.concatLists
      (map (d: ''
        mkdir -p /var/lib/nomad-volumes/${d}
        chown -R nobody:nogroup /var/lib/nomad-volumes/${d}
      ''))
      (builtins.concatStringsSep "\n")
    ];
}
