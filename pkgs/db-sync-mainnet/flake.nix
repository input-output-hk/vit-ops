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
      "https://update-cardano-mainnet.iohk.io/cardano-db-sync/11/db-sync-snapshot-schema-11-block-6426045-x86_64.tgz";
    restoreSnapshotSha =
      "a9b0787d1ad3e77c53394509505f04391a26bbbf9b92bfdccb4d4699d00c5a87";
  };
}
