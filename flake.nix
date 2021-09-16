{
  description = "Bitte for VIT";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    bitte.inputs.bitte-cli.url = "github:input-output-hk/bitte-cli";
    bitte-iogo.url = "github:manveru/bitte-iogo";
    nix.url = "github:NixOS/nix";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    terranix.follows = "bitte/terranix";
    utils.url = "github:kreisys/flake-utils";
    jormungandr-nix = {
      url = "github:input-output-hk/jormungandr-nix";
      flake = false;
    };
    jormungandr.url =
      "github:input-output-hk/jormungandr/8178bc9149ea4629c8ae6f87bdd5be4a154db322";
    vit-servicing-station.url =
      "github:input-output-hk/vit-servicing-station/a0d61cbb69608a834cfe30b60d526822fb69b47e";

    cardano-node = {
      # custom-config handling patch on top of 1.29:
      url =
        "github:input-output-hk/cardano-node/397078b4c302e2983a7c060778bcb062aa3435b7";
      inputs.customConfig.url = "path:./pkgs/node-custom-config";
    };

    cardano-db-sync-testnet = {
      url =
        "github:input-output-hk/cardano-db-sync/68f695e02ecac301399d282d089c32d6a50f7d08";
      inputs.customConfig.url = "path:./pkgs/db-sync-testnet";
    };

    cardano-db-sync-mainnet = {
      url =
        "github:input-output-hk/cardano-db-sync/68f695e02ecac301399d282d089c32d6a50f7d08";
      inputs.customConfig.url = "path:./pkgs/db-sync-mainnet";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, utils, bitte, nix, ... }@inputs:
    utils.lib.simpleFlake {
      inherit nixpkgs;
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte nix.overlay ];
      overlay = import ./overlay.nix { inherit inputs self; };

      extraOutputs = let
        hashiStack = bitte.lib.mkHashiStack {
          flake = self // {
            inputs = self.inputs // { inherit (bitte.inputs) terranix; };
          };
          domain = "vit.iohk.io";
        };
      in {
        inherit self inputs;
        inherit (hashiStack)
          clusters nomadJobs nixosConfigurations consulTemplates;
      };

      packages = { checkFmt, checkCue, nix, nixFlakes, node-scripts
        , db-sync-testnet-scripts, db-sync-mainnet-scripts, postgres-entrypoint
        }@pkgs:
        pkgs // {
          "testnet/node" = node-scripts.testnet.node;
          "mainnet/node" = node-scripts.mainnet.node;
          "testnet/db-sync" = db-sync-testnet-scripts.testnet.db-sync;
          "mainnet/db-sync" = db-sync-mainnet-scripts.mainnet.db-sync;
        };

      devShell = { bitteShellCompat, cue }:
        (bitteShellCompat {
          inherit self;
          extraPackages = [ cue ];
          cluster = "vit-testnet";
          profile = "vit";
          region = "eu-central-1";
          domain = "vit.iohk.io";
        });
    };
}
