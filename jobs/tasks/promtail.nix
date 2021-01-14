{ rev, ... }: {
  driver = "exec";

  config = {
    flake = "github:input-output-hk/vit-ops?rev=${rev}#grafana-loki";
    command = "/bin/promtail";
    args = [ "-config.file" "local/config.yaml" ];
  };

  templates = [
    {
      data = ''
        server:
          http_listen_port: 9080
          grpc_listen_port: 0

        positions:
          filename: /local/positions.yaml # This location needs to be writeable by promtail.

        client:
          url: http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:3100/loki/api/v1/push

        scrape_configs:
         - job_name: {{ env "NOMAD_GROUP_NAME" }}
           pipeline_stages:
           static_configs:
           - labels:
              syslog_identifier: {{ env "NOMAD_GROUP_NAME" }}
              namespace: {{ env "NOMAD_NAMESPACE" }}
              dc: {{ env "NOMAD_DC" }}
              host: {{ env "HOSTNAME" }}
              __path__: /alloc/logs/*.std*.0
      '';

      destination = "local/config.yaml";
    }
  ];
}
