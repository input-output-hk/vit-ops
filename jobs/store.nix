{ mkNomadJob, systemdSandbox, writeShellScript, coreutils, lib, ... }:
let jobPrefix = "vit-store";
in {
  ${jobPrefix} = mkNomadJob jobPrefix {
    datacenters = [ "us-east-2" ];
    taskGroups = {
      ${jobPrefix} = {
        tasks.${jobPrefix} = systemdSandbox {
          mountPaths = {
            "${jobPrefix}" = "/persistent";
          };

          name = jobPrefix;

          command = writeShellScript "store" ''
            cd $NOMAD_TASK_DIR

            set -x

            echo Attempt 6

            for i in $(seq 1 120); do
              echo "$i $(date)"
              ls -laR
              cat persistent/goodbye || true
              echo $i $RANDOM > persistent/goodbye || true
              sleep 1
            done
          '';

          env = { PATH = lib.makeBinPath [ coreutils ]; };

          resources = {
            cpu = 100; # mhz
            memoryMB = 1 * 128;
          };
        };
      };
    };
  };
}
