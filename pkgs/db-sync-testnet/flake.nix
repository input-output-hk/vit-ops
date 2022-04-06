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
      "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3449719-x86_64.tgz";
    restoreSnapshotSha =
      "6f416afcbe7acc27df283c47124679d684b4fb1d003a1ec7e03ec2accd1f80b7";
  };
}
