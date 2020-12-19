{ ... }: {
  services.grafana.provision.dashboards = [{
    name = "provisioned-vit-ops";
    options.path = ../../../contrib/dashboards;
  }];
}
