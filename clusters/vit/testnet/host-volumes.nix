{ config, self, lib, pkgs, ... }:
let
  namespaces = builtins.attrNames config.services.nomad.namespaces;
  isLocal = namespace: lib.hasPrefix "catalyst-sync-" namespace;
  isGluster = namespace: !(isLocal namespace);

  volumes = {
    local = lib.filter isLocal namespaces;
    gluster = lib.filter isGluster namespaces;
  };

  mkVolumes = names: pathFun:
    lib.listToAttrs (lib.forEach names (name: {
      inherit name;
      value = {
        path = pathFun name;
        read_only = false;
      };
    }));

  local_volumes = mkVolumes volumes.local (n: "/var/lib/nomad-volumes/${n}");
  gluster_volumes = mkVolumes volumes.gluster (n: "/mnt/gv0/nomad/${n}");
in {
  imports = [ (self.inputs.bitte + /profiles/glusterfs/client.nix) ];

  services.nomad.client = {
    chroot_env = {
      "/etc/passwd" = "/etc/passwd";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/services" = "/etc/services";
    };

    host_volume = [ (gluster_volumes // local_volumes) ];
  };

  system.activationScripts.nomad-host-volumes-local = ''
    set -xu
    export PATH="${lib.makeBinPath (with pkgs; [ fd coreutils ])}:$PATH"
  '' + (lib.pipe volumes.local [
    (map (d: ''
      mkdir -p /var/lib/nomad-volumes/${d}
      fd . -o root /var/lib/nomad-volumes/${d} -X chown nobody:nogroup
    ''))
    (builtins.concatStringsSep "\n")
  ]);

  system.activationScripts.nomad-host-volumes-gluster = ''
    set -xu
    export PATH="${lib.makeBinPath (with pkgs; [ fd coreutils ])}:$PATH"
  '' + (lib.pipe volumes.gluster [
    (map (d: ''
      mkdir -p /mnt/gv0/nomad/${d}
    ''))
    (builtins.concatStringsSep "\n")
  ]);
}
