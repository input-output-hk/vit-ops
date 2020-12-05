{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib, cacert, curl
, dnsutils, gawk, gnugrep, iproute, jq, lsof, netcat, nettools, procps
, jormungandr-monitor, jormungandr, telegraf, remarshal, dockerImages }:
let
  namespace = "catalyst-dryrun";

  block0 = {
    source =
      "s3::https://s3-eu-central-1.amazonaws.com/iohk-vit-artifacts/block0.bin";
    destination = "local/block0.bin";
    options.checksum =
      "sha256:4565c7888086569f86ec081f745f1261bc8f64b08aa3495c7a7aa458c3271cfe";
  };

  mkVit = { index, requiredPeerCount, backup ? false, public ? false }:
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
          monitor =
            import ./tasks/monitor.nix { inherit dockerImages namespace name; };
          env = import ./tasks/env.nix { inherit dockerImages; };
          telegraf = import ./tasks/telegraf.nix {
            inherit dockerImages namespace name;
          };
          jormungandr = import ./tasks/jormungandr.nix {
            inherit lib dockerImages namespace name requiredPeerCount public
              block0 index;
          };
        }) // (lib.optionalAttrs backup {
          backup = import ./tasks/backup.nix {
            inherit dockerImages namespace name block0;
          };
        });

        services."${namespace}-${name}-jormungandr" = {
          addressMode = "host";
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
          addressMode = "host";
          portLabel = "rpc";
          task = "jormungandr";
          tags = [ name "peer" role ];
        };

        services."${namespace}-jormungandr-internal" = {
          portLabel = "rpc";
          task = "jormungandr";
          tags = [ name "peer" role ];
        };

        services."${namespace}-${name}-jormungandr-rest" = {
          addressMode = "host";
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
    datacenters = [ "eu-central-1" "us-east-2" ];
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
    }) // (mkVit {
      index = 1;
      public = false;
      requiredPeerCount = 1;
    }) // (mkVit {
      index = 2;
      public = false;
      requiredPeerCount = 2;
    }) // (mkVit {
      index = 0;
      public = true;
      requiredPeerCount = 3;
    });
  };

  "${namespace}-backup" = mkNomadJob "backup" {
    datacenters = [ "eu-central-1" "us-east-2" ];
    type = "batch";
    inherit namespace;

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
    });
  };
}
