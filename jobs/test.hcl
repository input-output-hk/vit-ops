job "test" {
  datacenters = ["eu-central-1"]
  type = "service"
  group "nspawn" {
    count = 1
    task "spawn" {
      driver = "nspawn"
      config {
        # image = "test"
        # resolv_conf = "copy-host"
        # read_only = true
        # user_namespacing = false
        ephemeral = true
        console = "read-only"
        image_download {
          url = "http://127.0.0.1:8080/v0/github/input-output-hk/vit-ops/ref/master/nspawn-test"
        }
      }
    }
  }
}
