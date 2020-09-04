{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib, block0, db
, vit-servicing-station, wget, gzip, gnutar, cacert }:
let
  run-vit = writeShellScript "vit" ''
    set -exuo pipefail

    home="''${NOMAD_ALLOC_DIR}"
    cd $home

    db="''${NOMAD_ALLOC_DIR}/database.db"
    cp ${db} "$db"
    chmod u+wr "$db"

    ${vit-servicing-station}/bin/vit-servicing-station-server \
      --block0-path ${block0} --db-url "$db"
  '';

  run-jormungandr = writeShellScript "jormungandr" ''
    set -exuo pipefail

    cd "''${NOMAD_ALLOC_DIR}"

    wget -O jormungandr.tar.gz https://github.com/input-output-hk/jormungandr/releases/download/nightly.20200903/jormungandr-0.9.1-nightly.20200903-x86_64-unknown-linux-musl-generic.tar.gz
    tar --no-same-permissions xvf jormungandr.tar.gz
    exec ./jormungandr
  '';
in {
  vit = mkNomadJob "vit" {
    datacenters = [ "us-east-2" ];
    type = "service";

    taskGroups.vit-servicing-station = {
      count = 1;
      services.vit-servicing-station = { };
      tasks.vit-servicing-station = systemdSandbox {
        name = "vit-servicing-station";
        command = run-vit;

        env = { PATH = lib.makeBinPath [ coreutils ]; };

        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
      };
    };

    taskGroups.jormungandr = {
      count = 1;

      services.jormungandr = { };

      tasks.jormungandr = systemdSandbox {
        name = "jormungandr";

        command = run-jormungandr;

        env = {
          PATH = lib.makeBinPath [ coreutils wget gnutar gzip ];
          SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        };

        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
      };
    };
  };
}
