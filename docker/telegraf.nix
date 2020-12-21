{ lib, buildLayeredImage, mkEnv, telegraf, debugUtils }: {
  telegraf = buildLayeredImage {
    name = "docker.vit.iohk.io/telegraf";
    config = {
      Entrypoint = [ "${telegraf}/bin/telegraf" ];

      Env = mkEnv { PATH = lib.makeBinPath debugUtils; };
    };
  };
}
