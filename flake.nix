{
  description = "Bitte for VIT";

  nixConfig.allow-import-from-derivation = "true";
  nixConfig.extra-substituters = [
    "https://vit.cachix.org"
    "https://hydra.iohk.io"
  ];
  nixConfig.extra-trusted-public-keys = [
    "vit.cachix.org-1:tuLYwbnzbxLzQHHN0fvZI2EMpVm/+R7AKUGqukc6eh8="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  ];

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    nix.url = "github:NixOS/nix";
    nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    terranix.follows = "bitte/terranix";
    utils.url = "github:kreisys/flake-utils";
    jormungandr.url =
      "github:input-output-hk/jormungandr/8178bc9149ea4629c8ae6f87bdd5be4a154db322";
    vit-servicing-station.url =
      "github:input-output-hk/vit-servicing-station/a0d61cbb69608a834cfe30b60d526822fb69b47e";

    cardano-node = {
      url = "github:input-output-hk/cardano-node/1.33.0";
      inputs.customConfig.url = "path:./pkgs/node-custom-config";
    };

    cardano-db-sync-testnet = {
      url = "github:input-output-hk/cardano-db-sync/12.0.2";
      inputs.customConfig.url = "path:./pkgs/db-sync-testnet";
    };

    cardano-db-sync-mainnet = {
      url = "github:input-output-hk/cardano-db-sync/12.0.2";
      inputs.customConfig.url = "path:./pkgs/db-sync-mainnet";
    };
  };

  outputs = { self, nixpkgs, utils, bitte, ... }@inputs:
    let

      system = "x86_64-linux";

      overlay = final: prev: (nixpkgs.lib.composeManyExtensions overlays) final prev;
      overlays = [ (import ./overlay.nix { inherit inputs self; }) bitte.overlay ];

      domain = "vit.iohk.io";

      bitteStack =
        let stack = bitte.lib.mkBitteStack {
          inherit domain self inputs pkgs;
          clusters = "${self}/clusters";
          deploySshKey = "./secrets/ssh-vit-testnet";
          hydrateModule = import ./hydrate.nix { inherit (bitte.lib) terralib; };
        };
        in
        stack // {
          deploy = stack.deploy // { autoRollback = false; };
        };

      pkgs = import nixpkgs {
        inherit overlays system;
        config.allowUnfree = true;
      };

    in
    {
      inherit overlay;
      legacyPackages.${system} = pkgs;

      devShell.${system} = let name = "vit-testnet"; in
        pkgs.bitteShell {
          inherit self domain;
          profile = "vit";
          cluster = name;
          namespace = "catalyst-dryrun";
          extraPackages = [ pkgs.cue ];
        };
    } // bitteStack;
}
