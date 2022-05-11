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
      "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3514204-x86_64.tgz";
    restoreSnapshotSha =
      "d0432e6a2dec2b6fce019ad1a31f124cd816df9c4dccd2317f5e71b05d794a78";
  };
}
