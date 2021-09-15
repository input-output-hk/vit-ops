{
  outputs = { ... }: {
    nixosModules.cardano-node = {
      nixosModules.cardano-db-sync = {
        service.cardano-db-sync = {
          stateDir = "/persist";
          extended = true;

          postgres = {
            generatePGPASS = true;
            generateDatabase = true;
            user = "cexplorer";
            database = "cexplorer";
            socketdir = "/alloc";
          };

          restoreSnapshot =
            "https://update-cardano-mainnet.iohk.io/cardano-db-sync/11/db-sync-snapshot-schema-11-block-6236059-x86_64.tgz";
          restoreSnapshotSha =
            "4be8a31a326467f2b946b5a851e56de86896e07babc03cfaa2467743c1b42676";
        };
      };
    };
  };
}
