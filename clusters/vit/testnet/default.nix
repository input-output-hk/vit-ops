{ self, lib, pkgs, config, ... }:
let
  inherit (self.inputs) bitte;
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;
in {
  imports = [ ./iam.nix ./terraform-storage.nix ./secrets.nix ];

  users.users.telegraf.group = "telegraf";
  users.groups.telegraf = { };

  users.users.ssm-user.group = "ssm-user";
  users.groups.ssm-user = { };

  users.users.oauth2_proxy.group = "oauth2_proxy";
  users.groups.oauth2_proxy = { };
  users.users.oauth2_proxy.isSystemUser = true;

  users.users.builder.group = "builder";
  users.groups.builder = { };
  users.users.builder.isSystemUser = true;

  # Try to work around Nix crashing.
  systemd.services.nomad.environment.GC_DONT_GC = "1";

  services.nomad.namespaces = {
    catalyst-dryrun.description = "Dryrun";
    catalyst-fund3.description = "Fund3";
    catalyst-fund4.description = "Fund4";
    catalyst-fund5.description = "Fund5";
    catalyst-fund6.description = "Fund6";
    catalyst-fund7.description = "Fund7";
    catalyst-fund8.description = "Fund8";
    catalyst-fund9.description = "Fund9";
    catalyst-perf.description = "Perf";
    catalyst-signoff.description = "Signoff";
    catalyst-sync.description = "Sync";
    catalyst-test.description = "Test";
  };

  nix = {
    binaryCaches = [ "https://hydra.iohk.io" ];

    binaryCachePublicKeys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
  };

  cluster = {
    name = "vit-testnet";

    adminNames = [ "michael.fellinger" "michael.bishop" "samuel.leathers" ];
    developerGithubNames = [ ];
    developerGithubTeamNames = [ "jormungandr" ];
    adminGithubTeamNames = [ "devops" "jormungandr-devops" ];
    domain = "vit.iohk.io";
    kms =
      "arn:aws:kms:eu-central-1:432820653916:key/c24899f3-2371-4492-bf9e-2d1e53bde6ec";
    s3Bucket = "iohk-vit-bitte";
    terraformOrganization = "vit";

    s3CachePubKey = lib.fileContents ../../../encrypted/nix-public-key-file;
    flakePath = ../../..;

    autoscalingGroups = let
      defaultModules = [
        bitte.profiles.client
        "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
        "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
        ./docker-auth.nix
        ./host-volumes.nix
        ./gluster-zfs-clients.nix
        ./fix-nvme.nix
      ];
    in lib.listToAttrs (lib.forEach [
      {
        # used for db-sync
        region = "eu-central-1";
        desiredCapacity = 3;
        instanceType = "r5a.2xlarge";
        volumeSize = 800;
      }
      { region = "us-east-2"; }
      { region = "eu-west-1"; }
    ] (args:
      let
        attrs = {
          desiredCapacity = 6;
          instanceType = "c5.4xlarge";
          volumeSize = 200;
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          node_class = "client";
          modules = defaultModules;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          securityGroupRules = {
            inherit (securityGroupRules) internet internal ssh;
          };
        } // args;
        asgName = "client-${attrs.region}-${
            builtins.replaceStrings [ "." ] [ "-" ] attrs.instanceType
          }";
      in lib.nameValuePair asgName attrs));

    instances = {
      core-1 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.0.10";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 100;

        modules =
          [ (bitte + /profiles/core.nix) (bitte + /profiles/bootstrapper.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };

        initialVaultSecrets = {
          consul = ''
            sops --decrypt --extract '["encrypt"]' ${
              config.secrets.encryptedRoot + "/consul-clients.json"
            } \
            | vault kv put kv/bootstrap/clients/consul encrypt=-
          '';

          nomad = ''
            sops --decrypt --extract '["server"]["encrypt"]' ${
              config.secrets.encryptedRoot + "/nomad.json"
            } \
            | vault kv put kv/bootstrap/clients/nomad encrypt=-
          '';
        };
      };

      core-2 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.1.10";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.xlarge";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 600;
        route53.domains = [
          "consul.${cluster.domain}"
          "docker.${cluster.domain}"
          "monitoring.${cluster.domain}"
          "nomad.${cluster.domain}"
          "vault.${cluster.domain}"
          "zipkin.${cluster.domain}"
        ];

        modules = [ ./monitoring-server.nix ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https docker-registry;
        };
      };

      routing = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.small";
        privateIP = "172.16.1.20";
        subnet = cluster.vpc.subnets.core-2;
        volumeSize = 30;
        route53.domains = [ "*.${cluster.domain}" ];

        modules = [ ./routing.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http routing;
        };
      };

      routing-bench = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.small";
        privateIP = "172.16.2.20";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 30;
        route53.domains = [ "perf-servicing-station.${cluster.domain}" ];

        modules = [ ./routing.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh http routing;
        };
      };

      storage-0 = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.small";
        privateIP = "172.16.0.50";
        volumeSize = 60;
        subnet = cluster.vpc.subnets.core-1;

        modules = [
          (bitte + /profiles/glusterfs/storage.nix)
          ./gluster-permissions.nix
          ./gluster-zfs.nix
        ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-1 = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.small";
        privateIP = "172.16.1.50";
        volumeSize = 60;
        subnet = cluster.vpc.subnets.core-2;

        modules =
          [ (bitte + /profiles/glusterfs/storage.nix) ./gluster-zfs.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };

      storage-2 = {
        ami = "ami-0a1a94722dcbff94c";
        instanceType = "t3a.small";
        privateIP = "172.16.2.50";
        volumeSize = 60;
        subnet = cluster.vpc.subnets.core-3;

        modules =
          [ (bitte + /profiles/glusterfs/storage.nix) ./gluster-zfs.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internal internet ssh;
        };
      };
    };
  };
}
