{
  description = "Bitte for VIT";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    # bitte.url = "path:/home/jlotoski/work/iohk/bitte-wt/bitte";
    # bitte.url = "path:/home/manveru/github/input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    terranix.follows = "bitte/terranix";
    utils.follows = "bitte/utils";
    jormungandr-nix = {
      url = "github:input-output-hk/jormungandr-nix";
      flake = false;
    };
    jormungandr.url = "github:input-output-hk/jormungandr/add-flake";
    vit-servicing-station.url = "github:input-output-hk/vit-servicing-station";
  };

  outputs = { self, nixpkgs, utils, bitte, ... }@inputs:
    let
      vitOpsOverlay = import ./overlay.nix { inherit inputs self; };
      bitteOverlay = bitte.overlay.x86_64-linux;

      hashiStack = bitte.mkHashiStack {
        flake = self;
        rootDir = ./.;
        inherit pkgs;
        domain = "vit.iohk.io";
      };

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (final: prev: { inherit (hashiStack) clusters dockerImages; })
          bitteOverlay
          vitOpsOverlay
        ];
      };
    in {
      inherit self;
      inherit (hashiStack) nomadJobs dockerImages clusters nixosConfigurations consulTemplates;
      inherit (pkgs) sources;
      legacyPackages.x86_64-linux = pkgs;
      devShell.x86_64-linux = pkgs.devShell;
    };
}
