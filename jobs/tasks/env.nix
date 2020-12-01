{ dockerImages }: {
  driver = "docker";
  config.image = dockerImages.env.id;
  resources = {
    cpu = 10; # mhz
    memoryMB = 10;
  };
}
