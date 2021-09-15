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
            "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/11/db-sync-snapshot-schema-11-block-2903962-x86_64.tgz";
          restoreSnapshotSha =
            "49faeb09f2d22ad8ee33494d80cfa50bef9a3322d9ab63b4da675b047c3fd873";
        };
      };
    };
  };
}
