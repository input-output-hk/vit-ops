{ self, config, pkgs, ... }: {
  imports = [ (self.inputs.bitte + /profiles/monitoring.nix) ./secrets.nix ];

  users.extraUsers.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKad42tJ+z7APPA7pJPRPKOy1FP2ZZZ4XtNi8i0Pq9Lk deployer0"
  ];

  services.grafana.provision.dashboards = [{
    name = "provisioned-vit-ops";
    options.path = ../../../contrib/dashboards;
  }];

  services.loki.configuration.table_manager = {
    retention_deletes_enabled = true;
    retention_period = "350d";
  };

  services.ingress-config = {
    extraConfig = ''
      backend zipkin
        default-server check maxconn 2000
        option httpchk HEAD /
        server zipkin 127.0.0.1:9411
    '';

    extraHttpsAcls = ''
      acl is_zipkin hdr(host) -i zipkin.${config.cluster.domain}
    '';

    extraHttpsBackends = ''
      use_backend zipkin if is_zipkin authenticated
      use_backend oauth_proxy if is_zipkin ! authenticated
    '';
  };

  systemd.services.zipkin = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zipkin-server}/bin/zipkin-server";
      Restart = "on-failure";
      RestartSec = "15s";
      StateDirectory = "zipkin";
      DynamicUser = true;
      User = "zipkin";
      Group = "zipkin";
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPriviledges = true;
    };
  };
}
