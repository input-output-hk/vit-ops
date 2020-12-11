{ dockerImages }: {
  driver = "docker";
  config.image = dockerImages.env;
  resources = {
    cpu = 10; # mhz
    memoryMB = 10;
  };
}
