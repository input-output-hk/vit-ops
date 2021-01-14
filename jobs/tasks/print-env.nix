{ rev }: {
  driver = "exec";

  config = {
    flake = "github:input-output-hk/vit-ops?rev=${rev}#print-env";
    command = "/bin/print-env";
  };

  resources = {
    cpu = 10; # mhz
    memoryMB = 10;
  };
}
