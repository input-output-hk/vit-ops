{ ... }: {
  imports = [
    (bitte + /profiles/monitoring.nix)
    ./secrets.nix
  ]

  services.grafana.provision.dashboards = [{
    name = "provisioned-vit-ops";
    options.path = ../../../contrib/dashboards;
  }];

  services.loki.configuration.table_manager = {
    retention_deletes_enabled = true;
    retention_period = "28d";
  };

  services.ingress-config = {
    extraConfig = "";
    extraHttpsBackends = "";
  };
}
