{ rev, mkNomadJob, artifacts, ... }:
let
  namespace = "catalyst-dryrun";
  datacenters = [ "eu-central-1" "us-east-2" ];
  meta = {
    ingressHost = "dryrun-servicing-station.vit.iohk.io";
    ingressCheck = ''
      http-check send meth GET uri /api/v0/node/stats
      http-check expect status 200
    '';
    ingressMode = "http";
    ingressBind = "*:443";
  };
in {
  "${namespace}-servicing-station" = mkNomadJob "servicing-station" {
    inherit datacenters namespace;

    taskGroups.servicing-station = {
      count = 1;

      networks = [{ ports = { web.to = 6000; }; }];

      services."${namespace}-servicing-station" = {
        addressMode = "host";
        portLabel = "web";
        tags = [ "ingress" namespace ];
        meta = meta // {
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
        meta = meta // {
          ingressIf =
            "{ path_beg /api/v0/account /api/v0/message /api/v0/settings /api/v0/vote }";
          ingressServer =
            "_${namespace}-follower-0-jormungandr-rest._tcp.service.consul";
        };
      };

      tasks = {
        servicing-station =
          import ./tasks/servicing-station.nix { inherit namespace rev artifacts; };
        promtail = import ./tasks/promtail.nix { inherit rev; };
      };
    };
  };
}
