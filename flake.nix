{
  description = "Bitte for VIT";

  inputs = {
    bitte.url = "github:input-output-hk/bitte/sanitize-exempt";
    bitte.inputs.bitte-cli.follows = "bitte-cli";
    bitte-cli.url = "github:input-output-hk/bitte-cli/785b71fd808de16e0705236540239e063454ef5f";
    # bitte-iogo.url = "github:manveru/bitte-iogo";
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
        "github:input-output-hk/cardano-db-sync/52f78bbd7767f95bf37cc9661833a84aee88af1c";
      inputs.customConfig.url = "path:./pkgs/db-sync-testnet";
    };

    cardano-db-sync-mainnet = {
      url =
        "github:input-output-hk/cardano-db-sync/7e049be27df4571db9595ce45c8f76c25dbdd909";
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
