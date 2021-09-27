{ config, pkgs, lib, ... }:
let
  inherit (pkgs.terralib) var;

  mkStorage = instance: name: extra:
    {
      availability_zone = var "aws_instance.${instance}.availability_zone";
      encrypted = true;
      iops = 3000; # 3000..16000
      size = 100; # GiB
      type = "gp3";
      kms_key_id = config.cluster.kms;
      throughput = 125; # 125..1000 MiB/s
    } // extra;

  mkAttachment = device: instance: name: {
    device_name = device;
    volume_id = var "aws_ebs_volume.${name}.id";
    instance_id = var "aws_instance.${instance}.id";
  };

  mkAttachments = device: suffix:
    lib.listToAttrs (map (n:
      let
        instance = "storage-${toString n}";
        name = "${instance}${suffix}";
      in lib.nameValuePair name (mkAttachment device instance name)) range);

  mkStorages = suffix: extra:
    lib.listToAttrs (map (n:
      let
        instance = "storage-${toString n}";
        name = "storage-${toString n}${suffix}";
      in lib.nameValuePair name (mkStorage instance name extra)) range);

  range = lib.range 0 2;

  db-attachments = mkAttachments "/dev/sdh" "";
  zfs-attachments = mkAttachments "/dev/sdi" "-zfs";
  db-storage = mkStorages "" { };
  zfs-storage = mkStorages "-zfs" {
    size = 200;
    iops = 16000;
    throughput = 1000;
  };
in {
  tf.core.configuration = {
    resource.aws_volume_attachment = db-attachments // zfs-attachments;
    resource.aws_ebs_volume = db-storage // zfs-storage;
  };
}
