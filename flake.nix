{
  description = "Bitte for VIT";

  inputs = {
    bitte-cli.follows = "bitte/bitte-cli";
    bitte.url = "github:input-output-hk/bitte";
    # bitte.url = "path:/home/manveru/github/input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    terranix.follows = "bitte/terranix";
    utils.url = "github:numtide/flake-utils";
    rust-libs = {
      url = "github:input-output-hk/rust-libs.nix";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, ... }:
    (utils.lib.eachSystem [ "x86_64-linux" ] (system: rec {
      overlay = import ./overlay.nix { inherit system self; };

      legacyPackages = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # for ssm-session-manager-plugin
        overlays = [ overlay ];
      };

      inherit (legacyPackages) devShell;

      packages = {
        inherit (legacyPackages) bitte nixFlakes sops vit-servicing-station;
        inherit (self.inputs.bitte.packages.${system})
          terraform-with-plugins cfssl consul;
      };


      apps.bitte = utils.lib.mkApp { drv = legacyPackages.bitte; };
    })) // (let
      pkgs = import nixpkgs {
        overlays = [ self.overlay.x86_64-linux ];
        system = "x86_64-linux";
      };
    in { inherit (pkgs) nixosConfigurations clusters nomadJobs; });
}
