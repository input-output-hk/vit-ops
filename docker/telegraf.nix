{ buildLayeredImage, telegraf }: {
  telegraf = buildLayeredImage {
    name = "docker.vit.iohk.io/telegraf";
    config.Entrypoint = [ "${telegraf}/bin/telegraf" ];
  };
}
