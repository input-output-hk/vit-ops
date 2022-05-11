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
      "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-7230633-x86_64.tgz";
    restoreSnapshotSha =
      "5325407ae9cfdd63c6ae9e63f03d5f5b86c53be9f3ab03526cc23852ce6bb443";
  };
}
