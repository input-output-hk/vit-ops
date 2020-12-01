{ dockerImages, namespace, name }: {
  driver = "docker";

  resources = {
    cpu = 100; # mhz
    memoryMB = 256;
  };

  config = {
    image = dockerImages.monitor.id;
    ports = [ "prometheus" ];
    labels = [{
      inherit namespace name;
      imageTag = dockerImages.monitor.image.imageTag;
    }];

    logging = {
      type = "journald";
      config = [{
        tag = "${name}-monitor";
        labels = "name,namespace,imageTag";
      }];
    };
  };

  templates = [{
    data = ''
      SLEEP_TIME="10"
      PORT="{{ env "NOMAD_PORT_prometheus" }}"
      JORMUNGANDR_API="http://{{ env "NOMAD_ADDR_rest" }}/api"
    '';
    env = true;
    destination = "local/env.txt";
  }];
}
