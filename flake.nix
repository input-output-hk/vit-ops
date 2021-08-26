{
  description = "Bitte for VIT";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    bitte.inputs.bitte-cli.url = "github:input-output-hk/bitte-cli/v0.3.4";
    nix.follows = "bitte/nix";
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
    cardano-node.url =
      "github:input-output-hk/cardano-node?rev=14229feb119cc3431515dde909a07bbf214f5e26";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, utils, bitte, nix, ... }@inputs:
    utils.lib.simpleFlake {
      inherit nixpkgs;
      systems = [ "x86_64-linux" ];

      preOverlays = [ bitte nix.overlay ];
      overlay = import ./overlay.nix { inherit inputs self; };

      extraOutputs =
        let
          hashiStack = bitte.lib.mkHashiStack {
            flake = self // {
              inputs = self.inputs // { inherit (bitte.inputs) terranix; };
            };
            domain = "vit.iohk.io";
          };
        in
        {
          inherit self inputs;
          inherit (hashiStack)
            clusters nomadJobs nixosConfigurations consulTemplates;
        };

      packages = { checkFmt, checkCue, nix, nixFlakes }@pkgs: pkgs;

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
