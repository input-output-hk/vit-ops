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
      "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/13/db-sync-snapshot-schema-13-block-3269999-x86_64.tgz";
    restoreSnapshotSha =
      "c020bb176b05f58ce1b15420f590c47c9e150efcba099a605215da46fc28322d";
  };
}
