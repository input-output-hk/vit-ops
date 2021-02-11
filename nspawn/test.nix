{ nixpkgs }:
nixpkgs.lib.makeOverridable nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ({ lib, pkgs, config, ... }: {
      imports = [ (nixpkgs + "/nixos/modules/profiles/minimal.nix") ];
      boot.isContainer = true;
      time.timeZone = "UTC";
      system.stateVersion = "20.09";
      services.sshd.enable = true;
      services.nginx.enable = true;
      networking.firewall.allowedTCPPorts = [ 80 ];
      users.users.root.password = "nixos";
      services.openssh.permitRootLogin = lib.mkDefault "yes";
      services.mingetty.autologinUser = lib.mkDefault "root";

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        autoResize = true;
        fsType = "ext4";
      };

      boot = {
        growPartition = true;
        kernelParams = [ "console=ttyS0" ];
        initrd.availableKernelModules = [ "uas" ];
      };

      system.activationScripts.link-init = ''
        mkdir -p /sbin
        ln -s /nix/var/nix/profiles/system/init /sbin/init
      '';

      system.build.raw = import (nixpkgs + "/nixos/lib/make-disk-image.nix") {
        inherit lib pkgs config;
        partitionTableType = "none";
        format = "raw";

        # additionalSpace = "1024M";
        diskSize = 1000;
      };
    })
  ];
}
