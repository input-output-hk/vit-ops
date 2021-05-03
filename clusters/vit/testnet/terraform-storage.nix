{ config, pkgs, ... }:
let
  inherit (pkgs.terralib) var;

  mkStorage = name: {
    availability_zone = var "aws_instance.${name}.availability_zone";
    encrypted = true;
    iops = 3000; # 3000..16000
    size = 100; # GiB
    type = "gp3";
    kms_key_id = config.cluster.kms;
    throughput = 125; # 125..1000 MiB/s
  };

  mkAttachment = name: {
    device_name = "/dev/sdh";
    volume_id = var "aws_ebs_volume.${name}.id";
    instance_id = var "aws_instance.${name}.id";
  };
in {
  tf.core.configuration = {
    resource.aws_volume_attachment = {
      storage-0 = mkAttachment "storage-0";
      storage-1 = mkAttachment "storage-1";
      storage-2 = mkAttachment "storage-2";
    };

    resource.aws_ebs_volume = {
      storage-0 = mkStorage "storage-0";
      storage-1 = mkStorage "storage-1";
      storage-2 = mkStorage "storage-2";
    };
  };
}
