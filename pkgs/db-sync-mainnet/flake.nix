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
      "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-7087276-x86_64.tgz";
    restoreSnapshotSha =
      "73cfca460ed64762fab880f7bd63957e2c369d84992e58c0f1215c5b44e43ed2";
  };
}
