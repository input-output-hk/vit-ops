{ dockerImages, namespace, name }: {
  driver = "docker";

  resources = {
    cpu = 100; # mhz
    memoryMB = 256;
  };

  config = {
    image = dockerImages.monitor;
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
      JORMUNGANDR_API="http://127.0.0.1:{{ env "NOMAD_ALLOC_PORT_rest" }}/api"
    '';
    env = true;
    destination = "local/env.txt";
  }];
}
