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
      "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3590461-x86_64.tgz";
    restoreSnapshotSha =
      "922bb683158f36380d9e54399a27ac3bb5d760bdd4bc55f00f35ea40ae6d0f5f";
  };
}
