{
  description = "Bitte for VIT";

  inputs = {
    bitte.url = "github:input-output-hk/bitte";
    # bitte.url = "path:/home/jlotoski/work/iohk/bitte-wt/bitte";
    # bitte.url = "path:/home/manveru/github/input-output-hk/bitte";
    nixpkgs.follows = "bitte/nixpkgs";
    terranix.follows = "bitte/terranix";
    utils.url = "github:numtide/flake-utils";
    rust-libs.url =
      "github:input-output-hk/rust-libs.nix/vit-servicing-station";
    ops-lib.url = "github:input-output-hk/ops-lib/zfs-image?dir=zfs";
    jormungandr-nix = {
      url = "github:input-output-hk/jormungandr-nix";
      flake = false;
    };
    vit-servicing-station = {
      url = "github:input-output-hk/vit-servicing-station";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, rust-libs, ops-lib, bitte, ... }@inputs:
    let
      vitOpsOverlay = import ./overlay.nix inputs;
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
      inherit (hashiStack) nomadJobs dockerImages clusters nixosConfigurations;
      inherit (pkgs) sources;
      legacyPackages = pkgs;
      devShell.x86_64-linux = pkgs.devShell;
    };
}
