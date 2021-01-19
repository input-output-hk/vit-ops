{ mkNomadJob, lib, rev, artifacts }:
let
  namespace = "catalyst-fund2";
  datacenters = [ "eu-central-1" "us-east-2" ];

  mkVit = { index, requiredPeerCount, backup ? false, public ? false
    , memoryMB ? 512 }:
    let
      localRpcPort = (if public then 10000 else 7000) + index;
      localRestPort = (if public then 11000 else 9000) + index;
      localPrometheusPort = 10000 + index;
      publicPort = 7100 + index;

      role =
        if public then "follower" else if backup then "backup" else "leader";
      name = "${role}-${toString index}";
    in {
      ${name} = {
        count = 1;

        ephemeralDisk = {
          sizeMB = 1024;
          migrate = true;
          sticky = true;
        };

        networks = [{
          mode = "bridge";
          ports = {
            prometheus.to = 6000;
            rest.to = localRestPort;
            rpc.to = localRpcPort;
          };
        }];

        services."${namespace}-${name}-monitor" = {
          portLabel = "prometheus";
          task = "monitor";
        };

        tasks = (lib.optionalAttrs (!backup) {
          monitor = import ./tasks/monitor.nix { inherit namespace name rev; };
          env = import ./tasks/print-env.nix { inherit rev; };
          telegraf =
            import ./tasks/telegraf.nix { inherit namespace name rev; };
          jormungandr = import ./tasks/jormungandr.nix {
            inherit lib namespace name requiredPeerCount public artifacts index
              memoryMB rev;
          };
        }) // (lib.optionalAttrs backup {
          backup = import ./tasks/backup.nix {
            inherit namespace name artifacts memoryMB rev;
          };
        });

        services."${namespace}-${name}-jormungandr" = {
          portLabel = "rpc";
          task = "jormungandr";
          tags = [ name role ] ++ (lib.optional public "ingress");
          meta = lib.optionalAttrs public {
            ingressHost = "${name}.vit.iohk.io";
            ingressPort = toString publicPort;
            ingressBind = "*:${toString publicPort}";
            ingressMode = "tcp";
            ingressServer =
              "_${namespace}-${name}-jormungandr._tcp.service.consul";
            ingressBackendExtra = ''
              option tcplog
            '';
          };
        };

        services."${namespace}-jormungandr" = {
          portLabel = "rpc";
          task = "jormungandr";
          tags = [ name "peer" role ];
        };

        services."${namespace}-jormungandr-internal" =
          lib.mkIf (role != "backup") {
            portLabel = "rpc";
            task = "jormungandr";
            tags = [ name "peer" role ];
          };

        services."${namespace}-${name}-jormungandr-rest" = {
          portLabel = "rest";
          task = "jormungandr";
          tags = [ name role ];

          checks = [{
            type = "http";
            path = "/api/v0/node/stats";
            portLabel = "rest";

            checkRestart = {
              limit = 5;
              grace = "300s";
              ignoreWarnings = false;
            };
          }];
        };
      };
    };
in {
  ${namespace} = mkNomadJob "vit" {
    type = "service";
    inherit namespace;

    update = {
      maxParallel = 1;
      healthCheck = "checks";
      minHealthyTime = "30s";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      # autoRevert = true;
      # autoPromote = true;
      # canary = 1;
      stagger = "1m";
    };

    taskGroups = (mkVit {
      index = 0;
      public = false;
      requiredPeerCount = 0;
      memoryMB = 2048;
    }) // (mkVit {
      index = 1;
      public = false;
      requiredPeerCount = 1;
      memoryMB = 2048;
    }) // (mkVit {
      index = 2;
      public = false;
      requiredPeerCount = 2;
      memoryMB = 2048;
    }) // (mkVit {
      index = 0;
      public = true;
      requiredPeerCount = 3;
      memoryMB = 2048;
    });
  };

  "${namespace}-passive" = mkNomadJob "passive" {
    type = "service";
    inherit namespace datacenters;

    update = {
      maxParallel = 1;
      healthCheck = "checks";
      minHealthyTime = "30s";
      healthyDeadline = "5m";
      progressDeadline = "10m";
      # autoRevert = true;
      # autoPromote = true;
      # canary = 1;
      stagger = "1m";
    };

    taskGroups = mkVit {
      index = 1;
      public = true;
      requiredPeerCount = 1;
    };
  };

  "${namespace}-backup" = mkNomadJob "backup" {
    type = "batch";
    inherit namespace datacenters;

    periodic = {
      cron = "15 */1 * * * *";
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    taskGroups = (mkVit {
      index = 0;
      public = false;
      backup = true;
      requiredPeerCount = 3;
      memoryMB = 2048;
    });
  };
}

