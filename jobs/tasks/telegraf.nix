{ dockerImages, namespace, name }: {
  driver = "docker";

  vault = {
    policies = [ "nomad-cluster" ];
    changeMode = "noop";
  };

  resources = {
    cpu = 100; # mhz
    memoryMB = 128;
  };

  config = {
    image = dockerImages.telegraf.id;
    args = [ "-config" "local/telegraf.config" ];
    labels = [{
      inherit namespace name;
      imageTag = dockerImages.telegraf.image.imageTag;
    }];

    logging = {
      type = "journald";
      config = [{
        tag = "${name}-telegraf";
        labels = "name,namespace,imageTag";
      }];
    };
  };

  templates = [{
    data = ''
      [agent]
      flush_interval = "10s"
      interval = "10s"
      omit_hostname = false

      [global_tags]
      client_id = "${name}"
      namespace = "${namespace}"

      [inputs.prometheus]
      metric_version = 1

      urls = [ "http://{{ env "NOMAD_ADDR_prometheus" }}" ]

      [outputs.influxdb]
      database = "telegraf"
      urls = ["http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:8428"]
    '';

    destination = "local/telegraf.config";
  }];
}
