{ namespace, name, rev }: {
  driver = "exec";

  resources = {
    cpu = 100; # mhz
    memoryMB = 256;
  };

  config = {
    flake =
      "github:input-output-hk/vit-ops?rev=${rev}#jormungandr-monitor-entrypoint";
    command = "/bin/entrypoint";
    args = [ "-config" "local/telegraf.config" ];
  };

  templates = [{
    data = ''
      SLEEP_TIME="10"
      PORT="{{ env "NOMAD_HOST_PORT_prometheus" }}"
      JORMUNGANDR_API="http://{{ env "NOMAD_HOST_ADDR_rest" }}/api"
    '';
    env = true;
    destination = "local/env.txt";
  }];
}
