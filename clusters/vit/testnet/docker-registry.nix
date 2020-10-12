{ ... }: {
  services = {
    dockerRegistry = {
      enable = true;
      enableDelete = true;
      enableGarbageCollect = true;
      enableRedisCache = true;
    };

    redis.enable = true;
  };

  secrets.install.redis-password = {
    source = config.secrets.encryptedRoot + "/redis-password.json";
    target = /etc/consul.d/secrets.json;
  };

  secrets.generate.redis-password = ''
    export PATH="${lib.makeBinPath (with pkgs; [ coreutils sops xkcdpass ])}"

    if [ ! -s encrypted/redis-password.json ]; then
      xkcdpass \
      | sops --encrypt --kms '${kms}' /dev/stdin \
      > encrypted/redis-password.json
    fi
  '';

  secrets.install.redis-password = {
    source = config.secrets.encryptedRoot + "/redis-password.json";
    target = /run/keys/redis-password;
    inputType = "binary";
    outputType = "binary";
  };
}
