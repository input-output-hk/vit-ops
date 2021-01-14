{ namespace, name, rev }: {
  driver = "exec";

  vault = {
    policies = [ "nomad-cluster" ];
    changeMode = "noop";
  };

  resources = {
    cpu = 100; # mhz
    memoryMB = 128;
  };

  config = {
    flake = "github:input-output-hk/vit-ops?rev=${rev}#telegraf";
    command = "/bin/telegraf";
    args = [ "-config" "local/telegraf.config" ];
  };

  templates = [{
    data = ''
      [agent]
      flush_interval = "10s"
      interval = "10s"
      omit_hostname = false

      [global_tags]
      client_id = "{{ env "NOMAD_GROUP_NAME" }}"
      namespace = "{{ env "NOMAD_NAMESPACE" }}"

      [inputs.prometheus]
      metric_version = 1

      urls = [ "http://127.0.0.1:{{ env "NOMAD_PORT_prometheus" }}" ]

      [outputs.influxdb]
      database = "telegraf"
      urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
    '';

    destination = "local/telegraf.config";
  }];
}
