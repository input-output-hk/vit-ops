{ dockerImages, mkNomadJob, ... }:
let namespace = "catalyst-fund2";
in {
  "${namespace}-servicing-station" = mkNomadJob "servicing-station" {
    datacenters = [ "eu-central-1" "us-east-2" ];
    type = "service";
    inherit namespace;

    taskGroups.servicing-station = {
      count = 1;

      networks = [{ ports = { web.to = 6000; }; }];

      services."${namespace}-servicing-station" = {
        addressMode = "host";
        portLabel = "web";
        tags = [ "ingress" namespace ];
        meta = {
          ingressHost = "servicing-station.vit.iohk.io";
          ingressCheck = ''
            http-check send meth GET uri /api/v0/graphql/playground
            http-check expect status 200
          '';
          ingressMode = "http";
          ingressBind = "*:443";
          # TODO: remove playground in production
          ingressIf =
            "{ path_beg /api/v0/block0 /api/v0/fund /api/v0/proposals /api/v0/graphql/playground /api/v0/graphql }";
          ingressBackendExtra = ''
            acl is_origin_null req.hdr(Origin) -i null
            http-request del-header Origin if is_origin_null
          '';
          ingressServer = "_${namespace}-servicing-station._tcp.service.consul";
        };
      };
      services."${namespace}-servicing-station-jormungandr" = {
        addressMode = "host";
        portLabel = "web";
        tags = [ "ingress" namespace ];
        meta = {
          ingressHost = "servicing-station.vit.iohk.io";
          ingressCheck = ''
            http-check send meth GET uri /api/v0/node/stats
            http-check expect status 200
          '';
          ingressMode = "http";
          ingressBind = "*:443";
          # TODO: remove playground in production
          ingressIf =
            "{ path_beg /api/v0/account /api/v0/message /api/v0/settings /api/v0/vote }";
          ingressServer =
            "_${namespace}-follower-0-jormungandr-rest._tcp.service.consul";
        };
      };

      tasks.servicing-station = {
        driver = "docker";

        config = {
          image = dockerImages.vit-servicing-station;
          args = [ "--in-settings-file" "local/station-config.yaml" ];
          ports = [ "web" ];
          labels = [{
            inherit namespace;
            name = "${namespace}-servicing-station";
            imageTag = dockerImages.vit-servicing-station.image.imageTag;
          }];

          logging = {
            type = "journald";
            config = [{
              tag = "${namespace}-servicing-station";
              labels = "name,namespace,imageTag";
            }];
          };
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
              "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
            destination = "local/block0.bin";
            options.checksum =
              "sha256:4322205788954815a3a78c0d69e5bf0e695caa07b05196e09f1c0522379faac3";
          }
          {
            source =
              "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/database.sqlite3";
            destination = "local/database.sqlite3";
            options.checksum =
              "sha256:28205ca65610ce70a0e61531996f4f65ff58cf7a0ffca521471c9aa4899bf6f4";
          }
        ];
      };
    };
  };
}
