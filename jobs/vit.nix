{ mkNomadJob, vit-servicing-station, lib, writeShellScript, writeText }:

let
  zone = "us-east-2";
  runNode = writeShellScript "run-vit" ''
    export PATH=${lib.makeBinPath [ vit-servicing-station ]}
    mkdir -pv db
    vit-servicing-station-server \
      --block0-path TODO
  '';
  bar = {
    Job = {
      Affinities = null;
      AllAtOnce = null;
      Constraints = null;
      Datacenters = [ zone ];
      ID = "vit-servicing-station";
      Meta = null;
      Migrate = null;
      name = "vit-servicing-station";
      Namespace = null;
      ParameterizedJob = null;
      Periodic = null;
      Priority = null;
      Region = null;
      Reschedule = null;
      Spreads = null;
      TaskGroups = [
        {
          Affinities = null;
          Constraints = null;
          Count = 1;
          EphemeralDisk = null;
          Meta = null;
          Migrate = null;
          Name = "vit-servicing-station";
          Networks = [ { Mode = "bridge"; } ];
          Restart = null;
          Services = [
            {
              Connect = null;
              Name = "vit-servicing-station-node";
              PortLabel = null;
            }
          ];
          ShutdownDelay = null;
          Spreads = null;
          Tasks = [
            {
              Artifact = null;
              Config = {
                command = "/bin/sh";
                args = [
                  "-c"
                  ''
                    nix-store -r ${runNode}
                    exec nix-build -E 'builtins.derivation { name = "name-'$NOMAD_ALLOC_ID'"; outputHashAlgo = "sha256"; outputHashMode = "recursive"; outputHash = "0000000000000000000000000000000000000000000000000000"; builder = [ (builtins.storePath ${runNode}) ]; args = []; system = builtins.currentSystem; allowSubstitutes = false; }'
                  ''
                ];
              };
              Constraints = null;
              Driver = "raw_exec";
              Env = null;
              KillSignal = "";
              Name = "vit-servicing-station-node";
              Resources = {
                Cpu = 100;
                MemoryMB = 1024;
              };
              ShutdownDelay = 0;
              User = "";
            }
          ];
          Update = null;
        }
      ];
      Type = "service";
      Update = null;
    };
  };

in {
  #writeText "foo.json" (builtins.toJSON bar)
  vit = mkNomadJob "vit" {
    datacenters = [ zone ];
    type = "service";
    taskGroups.vit = {
      count = 1;
      services.vit = {};
      tasks.vit = {
        name = "vit";
        driver = "raw_exec";
        resources = {
          cpu = 100;
          memoryMB = 1024;
        };
        config = {
          command = "/bin/sh";
          args = [
            "-c"
            ''
              nix-store -r ${runNode}
              exec nix-build -E 'builtins.derivation { name = "name-'$NOMAD_ALLOC_ID'"; outputHashAlgo = "sha256"; outputHashMode = "recursive"; outputHash = "0000000000000000000000000000000000000000000000000000"; builder = [ (builtins.storePath ${runNode}) ]; args = []; system = builtins.currentSystem; allowSubstitutes = false; }'
            ''
          ];
        };
      };
    };
  };
}
