{ self, lib, pkgs, config, ... }:
let
  inherit (self.inputs) bitte;
  inherit (config) cluster;
  inherit (import ./security-group-rules.nix { inherit config pkgs lib; })
    securityGroupRules;
in {
  imports = [ ./iam.nix ];

  services.consul.policies.developer.servicePrefix."catalyst-" = {
    policy = "write";
    intentions = "write";
  };

  services.nomad.policies.admin.namespace."catalyst-*".policy = "write";
  services.nomad.policies.developer = {
    hostVolume."catalyst-*".policy = "write";
    namespace."catalyst-*" = {
      capabilities = [
        "submit-job"
        "dispatch-job"
        "read-logs"
        "alloc-exec"
        "alloc-node-exec"
        "alloc-lifecycle"
      ];
      policy = "write";
    };
  };

  services.nomad.namespaces = {
    catalyst-dryrun = { description = "Catalyst (dryrun)"; };
    catalyst-fund3 = { description = "Catalyst (fund3) "; };
    catalyst-sync = { description = "Catalyst (sync) "; };
    catalyst-perf = { description = "Catalyst (perf)"; };
    catalyst-test = { description = "Catalyst (test)"; };
  };

  nix = {
    binaryCaches = [
      "https://vit-ops.cachix.org"
      "https://hydra.iohk.io"
      "https://hydra.mantis.ist"
    ];

    binaryCachePublicKeys = [
      "vit-ops.cachix.org-1:LY84nIKdW7g1cvhJ6LsupHmGtGcKAlUXo+l1KByoDho="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "hydra.mantis.ist-1:4LTe7Q+5pm8+HawKxvmn2Hx0E3NbkYjtf1oWv+eAmTo="
    ];
  };

  cluster = {
    name = "vit-testnet";

    adminNames = [ "michael.fellinger" "michael.bishop" "samuel.leathers" ];
    developerGithubNames = [ ];
    developerGithubTeamNames = [ "jormungandr" ];
    domain = "vit.iohk.io";
    kms =
      "arn:aws:kms:eu-central-1:432820653916:key/c24899f3-2371-4492-bf9e-2d1e53bde6ec";
    s3Bucket = "iohk-vit-bitte";
    terraformOrganization = "vit";

    s3CachePubKey = lib.fileContents ../../../encrypted/nix-public-key-file;
    flakePath = ../../..;

    autoscalingGroups = let
      defaultModules = [
        (bitte + /profiles/client.nix)
        self.inputs.ops-lib.nixosModules.zfs-runtime
        "${self.inputs.nixpkgs}/nixos/modules/profiles/headless.nix"
        "${self.inputs.nixpkgs}/nixos/modules/virtualisation/ec2-data.nix"
        ./secrets.nix
        ./docker-auth.nix
        ./host-volumes.nix
        ./nspawn.nix
      ];

      withNamespace = name:
        pkgs.writeText "nomad-tag.nix" ''
          { services.nomad.client.meta.namespace = "${name}"; }
        '';

      mkModules = name: defaultModules ++ [ "${withNamespace name}" ];
    in lib.listToAttrs (lib.forEach [
      {
        region = "eu-central-1";
        desiredCapacity = 3;
        modules = mkModules "catalyst-dryrun";
      }
      {
        region = "us-east-2";
        desiredCapacity = 3;
        modules = mkModules "catalyst-fund2";
      }
      {
        region = "eu-west-1";
        desiredCapacity = 3;
        instanceType = "c5.4xlarge";
        volumeSize = 200;
        modules = mkModules "catalyst-sync";
      }
    ] (args:
      let
        attrs = ({
          desiredCapacity = 1;
          instanceType = "t3a.large";
          associatePublicIP = true;
          maxInstanceLifetime = 0;
          iam.role = cluster.iam.roles.client;
          iam.instanceProfile.role = cluster.iam.roles.client;

          securityGroupRules = {
            inherit (securityGroupRules) internet internal ssh;
          };
        } // args);
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

        modules = [
          (bitte + /profiles/core.nix)
          (bitte + /profiles/bootstrapper.nix)
          ./secrets.nix
        ];

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

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      core-3 = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.2.10";
        subnet = cluster.vpc.subnets.core-3;
        volumeSize = 100;

        modules = [ (bitte + /profiles/core.nix) ./secrets.nix ];

        securityGroupRules = {
          inherit (securityGroupRules) internet internal ssh;
        };
      };

      monitoring = {
        instanceType = "t3a.xlarge";
        privateIP = "172.16.0.20";
        subnet = cluster.vpc.subnets.core-1;
        volumeSize = 300;
        route53.domains = [
          "consul.${cluster.domain}"
          "docker.${cluster.domain}"
          "monitoring.${cluster.domain}"
          "nomad.${cluster.domain}"
          "vault.${cluster.domain}"
        ];

        modules = [ ./monitoring-server.nix ];

        securityGroupRules = {
          inherit (securityGroupRules)
            internet internal ssh http https docker-registry;
        };
      };

      routing = {
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
    };
  };
}
