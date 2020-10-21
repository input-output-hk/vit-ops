{ config, ... }: {
  services.ingress-config.extraHttpsAcls = ''
    acl is_servicing_station hdr(host) -i servicing-station.${config.cluster.domain}
  '';

  services.ingress-config.extraHttpsBackends = ''
    use_backend servicing_station if is_servicing_station
  '';

  services.ingress-config.extraConfig = ''
    backend servicing_station
      mode http
      http-check send meth GET uri /api/v0/graphql/playground
      http-check expect status 200
      server-template vit-servicing-station 1 _vit-servicing-station._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check
  '';
}
