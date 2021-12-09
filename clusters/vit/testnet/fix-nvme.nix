{ lib, ... }: { boot.loader.grub.device = lib.mkForce "/dev/nvme0n1"; }
