job "vit-test" {
  datacenters = ["us-east-2"]

  group "vit-core" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "leader"

      connect {
        sidecar_service {}
      }
    }

    task "leader" {
      driver = "exec"

      vault {
        policies = [ "nomad-cluster" ]
      }

      config = {
        command = "local/jormungandr/jormungandr"
        args = [
          "--config",
          "local/node-config.yaml",
          "--genesis-block",
          "local/block0.bin",
          "--secret",
          "local/bft-secret.yaml"
        ]
      }

      artifact {
        source = "https://github.com/input-output-hk/jormungandr/releases/download/nightly.20200918/jormungandr-0.9.1-nightly.20200918-x86_64-unknown-linux-musl-generic.tar.gz"
        destination = "local/jormungandr"
        options = {
          checksum = "sha256:74f6399a96d0b9806006181d9ce94165e54521537968654ee308168f6f4d3a26"
        }
      }

      artifact {
        source = "https://github.com/input-output-hk/jormungandr/blob/master/testing/jormungandr-scenario-tests/test/Testing%20the%20network/block0.bin?raw=true"
        destination = "local"
        options = {
          checksum = "sha256:29a300fbe721ba9f63b8c87400452935b5a1ea95f06edd4898399444f44cb623"
        }
      }

      template {
        data = "{\"bft\": {\"signing_key\": \"{{with secret \"kv/data/nomad-cluster/bft/0\"}}{{.Data.data.value}}{{end}}\"}}"
        destination = "local/bft-secret.yaml"
      }
    }
  }
}
