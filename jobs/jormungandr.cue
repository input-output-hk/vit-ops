package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#Jormungandr: types.#stanza.job & {
	#block0: {url: string, checksum: string}
	#role:       "leader" | "follower"
	#index:      uint
	#name:       "\(#role)-\(#index)"
	#fqdn:       string
	#id:         "\(namespace)-\(#name)"
	#publicPort: 7200 + #index
	#flakes: #jormungandr: types.#flake
	#domain: string
	#rateLimit: {
		average: uint
		burst:   uint
		period:  types.#duration | *"1m"
	}
	#requiredPeerCount: uint
	if #role == "leader" {
		#requiredPeerCount: #index
	}
	if #role == "follower" {
		#requiredPeerCount: 3
	}

	namespace: string

	type: "service"
	group: "jormungandr": {
		network: {
			mode: "host"
			port: {
				rest: {}
				rpc: {}
				promtail: {}
			}
		}

		volume: "persist": {
			type:      "host"
			read_only: false
			source:    "\(namespace)"
		}

		ephemeral_disk: {
			size:    1024
			migrate: true
			sticky:  true
		}

		let ref = {
			role:              #role
			block0:            #block0
			requiredPeerCount: #requiredPeerCount
			index:             #index
		}

		task: "jormungandr": tasks.#Jormungandr & {
			#namespace:         namespace
			#role:              ref.role
			#block0:            ref.block0
			#requiredPeerCount: ref.requiredPeerCount
			#index:             ref.index
			#flake:             #flakes.#jormungandr
		}

		task: "telegraf": tasks.#Telegraf & {
			#clientId:       "{{ env \"NOMAD_JOB_NAME\" }}"
		}

		task: "promtail": tasks.#Promtail

		service: "\(#id)": {
			address_mode: "host"
			port:         "rpc"
			task:         "jormungandr"
			if #role == "leader" {
				tags: [#name, #role]
			}
			if #role == "follower" {
				tags: [
					#name,
					#role,
					"traefik.enable=true",
					"traefik.tcp.routers.\(namespace)-jormungandr.rule=HostSNI(`*`)",
					"traefik.tcp.routers.\(namespace)-jormungandr.entrypoints=fund3",
				]
			}
		}

		service: "\(namespace)-jormungandr": {
			address_mode: "host"
			port:         "rpc"
			task:         "jormungandr"
			tags: [#name, #role, "peer"]
		}

		if #role != "backup" {
			service: "\(namespace)-jormungandr-internal": {
				address_mode: "host"
				port:         "rpc"
				task:         "jormungandr"
				tags: [#name, #role, "peer"]
			}
		}

		if #role == "follower" {
			service: "\(#id)-jormungandr-rest": {
				address_mode: "host"
				port:         "rest"
				task:         "jormungandr"

				check: "node-stats": {
					type:     "http"
					path:     "/api/v0/node/stats"
					port:     "rest"
					interval: "10s"
					timeout:  "1s"

					check_restart: {
						limit:           5
						grace:           "300s"
						ignore_warnings: false
					}
				}

				#paths: "/api/{x:(v0|v1)}/{y:(account|message|settings|vote|fragments|fragment|node).*}"

				tags: [
					#name,
					#role,
					namespace,
					"ingress",
					"traefik.enable=true",
					"traefik.http.routers.\(namespace)-jormungandr-rpc.rule=Host(`\(#domain)`) && Path(`\(#paths)`)",
					"traefik.http.routers.\(namespace)-jormungandr-rpc.entrypoints=https",
					"traefik.http.routers.\(namespace)-jormungandr-rpc.tls=true",
					"traefik.http.routers.\(namespace)-jormungandr-rpc.middlewares=\(namespace)-rpc-ratelimit@consulcatalog, \(namespace)-rpc-remove-origin@consulcatalog, \(namespace)-rpc-cors-headers@consulcatalog",
					"traefik.http.middlewares.\(namespace)-rpc-remove-origin.headers.customrequestheaders.Origin=http://127.0.0.1",
					"traefik.http.middlewares.\(namespace)-rpc-cors-headers.headers.accesscontrolallowmethods=GET,OPTIONS,PUT,POST",
					"traefik.http.middlewares.\(namespace)-rpc-cors-headers.headers.accesscontrolalloworiginlist=*",
					"traefik.http.middlewares.\(namespace)-rpc-cors-headers.headers.accesscontrolallowheaders=*",
					"traefik.http.middlewares.\(namespace)-rpc-cors-headers.headers.accesscontrolmaxage=100",
					"traefik.http.middlewares.\(namespace)-rpc-cors-headers.headers.addvaryheader=true",
					"traefik.http.middlewares.\(namespace)-rpc-ratelimit.ratelimit.average=\(#rateLimit.average)",
					"traefik.http.middlewares.\(namespace)-rpc-ratelimit.ratelimit.burst=\(#rateLimit.burst)",
					"traefik.http.middlewares.\(namespace)-rpc-ratelimit.ratelimit.period=\(#rateLimit.period)",
				]
			}
		}
	}
}
