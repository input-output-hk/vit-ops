{ system, self }:
final: prev: {
  # inject vault-bin into bitte wrapper
  bitte = let
    bitte-nixpkgs = import self.inputs.nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          vault-bin = self.inputs.bitte.legacyPackages.${system}.vault-bin;
        })
        self.inputs.bitte-cli.overlay.${system}
      ];
    };
  in bitte-nixpkgs.bitte;

  inherit (self.inputs.rust-libs.legacyPackages.${system})
    vit-servicing-station;

  nixFlakes = self.inputs.bitte.legacyPackages.${system}.nixFlakes;

  devShell = prev.mkShell {
    LOG_LEVEL = "debug";

    buildInputs = [
      final.bitte
      final.terraform-with-plugins
      prev.sops
      final.vault-bin
      final.glibc
      final.gawk
      final.openssl
      final.cfssl
      final.nixfmt
    ];
  };

  nixosConfigurations =
    self.inputs.bitte.legacyPackages.${system}.mkNixosConfigurations
    final.clusters;

  clusters = self.inputs.bitte.legacyPackages.${system}.mkClusters {
    root = ./clusters;
    inherit self system;
  };

  nomadJobs = final.callPackage ./jobs/vit.nix {
    block0 = "${self.inputs.vit-servicing-station}/docker/master/block0.bin";
    db = "${self.inputs.vit-servicing-station}/docker/master/database.db";
  };

  inherit (self.inputs.bitte.legacyPackages.${system})
    vault-bin mkNomadJob mkNomadTaskSandbox terraform-with-plugins;

  systemdSandbox = final.callPackage ./jobs/sandbox.nix { };
}
