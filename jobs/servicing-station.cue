package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"strings"
	"list"
)

#ServicingStation: types.#stanza.job & {
	#block0: {url: string, checksum: string}
	#database: {url: string, checksum: string}
	#vitOpsRev: string
	#domain:    string

	#servicingStationEndpoints: [
		"/api/v0/block0",
		"/api/v0/fund",
		"/api/v0/proposals",
		"/api/v0/graphql/playground",
		"/api/v0/graphql",
		"/api/v0/challenges",
		"/api/v1/fragments",
	]

	#jormungandrEndpoints: [
		"/api/v0/account",
		"/api/v0/message",
		"/api/v0/settings",
		"/api/v0/vote",
	]

	namespace:   string
	datacenters: list.MinItems(1)
	type:        "service"

	group: "servicing-station": {
		network: {
			mode: "host"
			port: "web": {}
			port: "promtail": {}
		}

		service: "\(namespace)-servicing-station": {
			address_mode: "host"
			port:         "web"
			tags: ["ingress", namespace]

			check: "health": {
				type:     "http"
				port:     "web"
				interval: "10s"
				path:     "/api/v0/health"
				timeout:  "2s"
			}

			meta: {
				IngressHost:   #domain
				IngressMode:   "http"
				IngressBind:   "*:443"
				IngressIf:     "{ path_beg \(strings.Join(#servicingStationEndpoints, " ")) }"
				IngressServer: "_\(namespace)-servicing-station._tcp.service.consul"
				IngressCheck: """
					http-check send meth GET uri /api/v0/graphql/playground
					http-check expect status 200
					"""
				IngressBackendExtra: """
					acl is_origin_null req.hdr(Origin) -i null
					http-request del-header Origin if is_origin_null
					"""
			}
		}

		service: "\(namespace)-servicing-station-jormungandr": {
			address_mode: "host"
			port:         "web"
			tags: ["ingress", namespace]
			check: "health": {
				type:     "http"
				port:     "web"
				interval: "10s"
				path:     "/api/v0/health"
				timeout:  "2s"
			}

			meta: {
				IngressHost:   #domain
				IngressMode:   "http"
				IngressBind:   "*:443"
				IngressIf:     "{ path_beg \(strings.Join(#jormungandrEndpoints, " ")) }"
				IngressServer: "_\(namespace)-follower-0-jormungandr-rest._tcp.service.consul"
				IngressCheck: """
					http-check send meth GET uri /api/v0/node/stats
					http-check expect status 200
					"""
				IngressBackendExtra: """
					acl is_origin_null req.hdr(Origin) -i null
					http-request del-header Origin if is_origin_null
					"""
			}
		}

		task: "servicing-station": {
			driver: "exec"

			config: {
				flake:   "github:input-output-hk/vit-servicing-station/use-rust-nix#vit-servicing-station-server"
				command: "/bin/vit-servicing-station-server"
				args: ["--in-settings-file", "local/station-config.yaml"]
			}

			env: {
				PATH: "/bin"
			}

			resources: {
				cpu:    100
				memory: 512
			}

			template: "local/station-config.yaml": {
				data: """
          {
            "tls": {
              "cert_file": null,
              "priv_key_file": null
            },
            "cors": {
              "allowed_origins": [ "https://\(#domain)", "http://127.0.0.1" ],
              "max_age_secs": null
            },
            "db_url": "local/database.sqlite3/database.sqlite3",
            "block0_path": "local/block0.bin/block0.bin",
            "enable_api_tokens": false,
            "log": {
              "log_level": "debug"
            },
            "address": "0.0.0.0:{{ env "NOMAD_PORT_web" }}"
          }
          """
			}

			artifact: "local/block0.bin": {
				source: #block0.url
				options: {
					checksum: #block0.checksum
				}
			}

			artifact: "local/database.sqlite3": {
				source: #database.url
				options: {
					checksum: #database.checksum
				}
			}
		}

		task: "promtail": {
			driver: "exec"

			config: {
				flake:   "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#grafana-loki"
				command: "/bin/promtail"
				args: ["-config.file", "local/config.yaml"]
			}

			template: "local/config.yaml": {
				data: """
					server:
					  http_listen_port: {{ env "NOMAD_PORT_promtail" }}
					  grpc_listen_port: 0

					positions:
					  filename: /local/positions.yaml # This location needs to be writeable by promtail.

					client:
					  url: http://{{with node "monitoring" }}{{ .Node.Address }}{{ end }}:3100/loki/api/v1/push

					scrape_configs:
					- job_name: {{ env "NOMAD_GROUP_NAME" }}
					  pipeline_stages:
					  static_configs:
					  - labels:
					      syslog_identifier: {{ env "NOMAD_GROUP_NAME" }}
					      namespace: {{ env "NOMAD_NAMESPACE" }}
					      dc: {{ env "NOMAD_DC" }}
					      host: {{ env "HOSTNAME" }}
					      __path__: /alloc/logs/*.std*.0
					"""
			}
		}
	}
}
