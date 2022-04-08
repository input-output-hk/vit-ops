{ terralib
, ...
}:

let

  inherit (terralib) var id;
  c = "create";
  r = "read";
  u = "update";
  d = "delete";
  l = "list";
  s = "sudo";

  secretsFolder = "encrypted";
  starttimeSecretsPath = "kv/nomad-cluster";
  # starttimeSecretsPath = "starttime"; # TODO: migrate job configs; use variables/constants -> nomadlib
  runtimeSecretsPath = "runtime";
in
{
  # cluster level
  # --------------
  tf.hydrate.configuration = {
    locals.policies = {
      vault.developer.path."kv/*".capabilities = [ c r u d l ];
      consul.developer = {
        service_prefix."catalyst-*" = {
          policy = "write";
          intentions = "write";
        };
      };
      nomad.admin.namespace."catalyst-*".policy = "write";
      nomad.developer = {
        host_volume."catalyst-*".policy = "write";
        namespace."catalyst-*" = {
          policy = "write";
          capabilities = [
            "submit-job"
            "dispatch-job"
            "read-logs"
            "alloc-exec"
            "alloc-node-exec"
            "alloc-lifecycle"
          ];
        };
      };
    };
  };
}
