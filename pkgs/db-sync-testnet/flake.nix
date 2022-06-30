{
  outputs = _: {
    enable = true;
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
      "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-7313329-x86_64.tgz";
    restoreSnapshotSha =
      "660ad796c928ca06f0095e46b324a850f0b3c100c8f89002e20220815ea8dc1b";
  };
}
