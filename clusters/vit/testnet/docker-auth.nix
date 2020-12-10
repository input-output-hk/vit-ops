{ pkgs, lib, config, ... }: {
  services.nomad.plugin.docker.auth.config =
    "/var/lib/nomad/.docker/config.json";

  secrets.install.docker-login = {
    source = config.secrets.encryptedRoot + "/docker-passwords.json";
    target = /run/keys/docker-passwords-decrypted;
    script = ''
      export PATH="${lib.makeBinPath (with pkgs; [ coreutils jq ])}"

      mkdir -p /root/.docker

      hashed="$(jq -r -e < /run/keys/docker-passwords-decrypted .password)"
      auth="$(echo -n "developer:$hashed" | base64)"
      ua="Docker-Client/19.03.12 (linux)"

      echo '{}' \
        | jq --arg auth "$auth" '.auths."docker.${config.cluster.domain}".auth = $auth' \
        | jq --arg ua "$ua" '.HttpHeaders."User-Agent" = $ua' \
        > /root/.docker/config.json

      mkdir -p /var/lib/nomad/.docker
      cp /root/.docker/config.json /var/lib/nomad/.docker/config.json
    '';
  };
}
