{ namespace, ... }: {
  driver = "exec";

  config = {
    flake = "github:input-output-hk/vit-ops?rev=95a2ec1d6a71d07b2ad15fe66e9753b25782e63a#vit-servicing-station";
    command = "/bin/vit-servicing-station-server";
    args = [ "--in-settings-file" "local/station-config.yaml" ];
  };

  env = {
    PATH = "/bin";
  };

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
      source =
        "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/${namespace}/block0.bin";
      destination = "local/block0.bin";
      options.checksum =
        "sha256:9cb70f7927201fd11f004de42c621e35e49b0edaf7f85fc1512ac142bcb9db0f";
    }
    {
      source =
        "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/${namespace}/database.sqlite3";
      destination = "local/database.sqlite3";
      options.checksum =
        "sha256:a0b6acd53ef6548c8aad64ee5d3b8699e1f10dfa5d8264637cfe87a10ac4efab";
    }
  ];
}
