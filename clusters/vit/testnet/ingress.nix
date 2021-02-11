{ config, ... }: {
  services.ingress-config.extraGlobalConfig = ''
    # debug
  '';

  services.ingress-config.extraHttpsFrontendConfig = ''
    # Prefer lua cors over custom config cors
    http-request lua.cors "*", "*", "*"
    http-response lua.cors

    # http-response set-header Access-Control-Allow-Origin "*"
    # http-response set-header Access-Control-Allow-Headers "Authorization, Origin, X-Requested-With, Content-Type, Accept"
    # http-response set-header Access-Control-Max-Age 3628800
    # http-response set-header Access-Control-Allow-Methods "GET, POST, OPTIONS, HEAD"
  '';
}
