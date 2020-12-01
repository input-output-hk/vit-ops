{ mkEnv, buildLayeredImage, restic-backup, debugUtils, cacert, restic }: {
  backup = buildLayeredImage {
    name = "docker.vit.iohk.io/backup";
    contents = [ restic cacert ] ++ debugUtils;
    config.Entrypoint = [ "${restic-backup}/bin/restic-backup" ];
    config.Env = mkEnv { AWS_DEFAULT_REGION = "eu-central-1"; };
  };
}
