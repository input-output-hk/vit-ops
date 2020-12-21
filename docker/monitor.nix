{ buildLayeredImage, mkEnv, jormungandr-monitor, cacert, busybox, debugUtils
}: {
  monitor = buildLayeredImage {
    name = "docker.vit.iohk.io/monitor";
    contents = [ busybox ] ++ debugUtils;
    config = {
      Entrypoint = [ jormungandr-monitor ];

      Env = mkEnv { SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt"; };
    };
  };
}
