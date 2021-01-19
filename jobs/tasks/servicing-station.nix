{ namespace, rev, artifacts, ... }: {
  driver = "exec";

  config = {
    flake = "github:input-output-hk/vit-ops?rev=${rev}#vit-servicing-station";
    command = "/bin/vit-servicing-station-server";
    args = [ "--in-settings-file" "local/station-config.yaml" ];
  };

  env = { PATH = "/bin"; };

  resources = {
    cpu = 100; # mhz
    memoryMB = 1 * 512;
  };

  templates = [{
    data = ''
      {
        "tls": {
          "cert_file": null,
          "priv_key_file": null
        },
        "cors": {
          "allowed_origins": [ "https://servicing-station.vit.iohk.io", "http://127.0.0.1" ],
          "max_age_secs": null
        },
        "db_url": "local/database.sqlite3/database.sqlite3",
        "block0_path": "local/block0.bin/block0.bin",
        "enable_api_tokens": false,
        "log": {
          "log_level": "debug"
        },
        "address": "0.0.0.0:{{ env "NOMAD_PORT_web" }}"
      }
    '';
    destination = "local/station-config.yaml";
  }];

  artifacts = [
    {
      source = artifacts.${namespace}.block0.url;
      destination = "local/block0.bin";
      options.checksum = artifacts.${namespace}.block0.checksum;
    }
    {
      source = artifacts.${namespace}.database.url;
      destination = "local/database.sqlite3";
      options.checksum = artifacts.${namespace}.database.checksum;
    }
  ];
}
