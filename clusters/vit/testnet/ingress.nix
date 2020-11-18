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

  services.ingress-config.extraHttpsBackends = ''
    {{ range services -}}
      {{ if .Tags | contains "ingress" -}}
        {{ range service .Name -}}
          {{ if (and (eq .ServiceMeta.IngressBind "*:443") .ServiceMeta.IngressServer) -}}
            use_backend {{ .ID }} if { hdr(host) -i {{ .ServiceMeta.IngressHost }} } {{ .ServiceMeta.IngressIf }}
          {{ end -}}
        {{ end -}}
      {{ end -}}
    {{ end -}}
  '';

  services.ingress-config.extraConfig = ''
    {{ range services -}}
      {{ if .Tags | contains "ingress" -}}
        {{ range service .Name -}}
          {{ if .ServiceMeta.IngressServer -}}
            backend {{ .ID }}
              mode {{ or .ServiceMeta.IngressMode "http" }}
              default-server resolve-prefer ipv4 resolvers consul resolve-opts allow-dup-ip
              {{ .ServiceMeta.IngressBackendExtra }}
              server {{.ID}} {{ .ServiceMeta.IngressServer }}

            {{ if (and .ServiceMeta.IngressBind (ne .ServiceMeta.IngressBind "*:443") ) }}
              frontend {{ .ID }}
                bind {{ .ServiceMeta.IngressBind }}
                mode {{ or .ServiceMeta.IngressMode "http" }}
                default_backend {{ .ID }}
            {{ end }}
          {{ end -}}
        {{ end -}}
      {{ end -}}
    {{ end }}
  '';
}
