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
      "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/11/db-sync-snapshot-schema-11-block-3022711-x86_64.tgz";
    restoreSnapshotSha =
      "45c8390db0b7bf49ff0b27beab29d15c657421e0188a8448c44f49e37f5f901a";
  };
}
