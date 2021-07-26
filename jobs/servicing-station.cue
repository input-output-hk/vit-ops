package jobs

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	"github.com/input-output-hk/vit-ops/pkg/jobs/tasks:tasks"
)

#ServicingStation: types.#stanza.job & {
	#block0: {url: string, checksum: string}
	#database: {url: string, checksum: string}
	#vitOpsRev: string
	#domain:    string
	#flakes: #servicingStation: types.#flake
	#version: string
	#rateLimit: {
		average: uint
		burst:   uint
		period:  types.#duration | *"1m"
	}

	namespace: string
	type:      "service"

	group: "servicing-station": {
		network: {
			mode: "host"
			port: "web": {}
			port: "promtail": {}
		}

		count: 2

		service: "\(namespace)-servicing-station": {
			address_mode: "host"
			port:         "web"

			#paths: "/api/{x:(vit-version|v0/(block0|fund|proposals|challenges).*)}"

			tags: [
				namespace,
				"ingress",
				"traefik.enable=true",
				"traefik.http.routers.\(namespace)-servicing-station.rule=Host(`\(#domain)`) && Path(`\(#paths)`)",
				"traefik.http.routers.\(namespace)-servicing-station.entrypoints=https",
				"traefik.http.routers.\(namespace)-servicing-station.tls=true",
				"traefik.http.routers.\(namespace)-servicing-station.middlewares=\(namespace)-vss-ratelimit@consulcatalog, \(namespace)-vss-remove-origin@consulcatalog, \(namespace)-vss-cors-headers@consulcatalog",
				"traefik.http.middlewares.\(namespace)-vss-remove-origin.headers.customrequestheaders.Origin=http://127.0.0.1",
				"traefik.http.middlewares.\(namespace)-vss-cors-headers.headers.accesscontrolallowmethods=GET,OPTIONS,PUT",
				"traefik.http.middlewares.\(namespace)-vss-cors-headers.headers.accesscontrolalloworiginlist=*",
				"traefik.http.middlewares.\(namespace)-vss-cors-headers.headers.accesscontrolmaxage=100",
				"traefik.http.middlewares.\(namespace)-vss-cors-headers.headers.addvaryheader=true",
				"traefik.http.middlewares.\(namespace)-vss-ratelimit.ratelimit.average=\(#rateLimit.average)",
				"traefik.http.middlewares.\(namespace)-vss-ratelimit.ratelimit.burst=\(#rateLimit.burst)",
				"traefik.http.middlewares.\(namespace)-vss-ratelimit.ratelimit.period=\(#rateLimit.period)",
			]

			check: "health": {
				type:     "http"
				port:     "web"
				interval: "10s"
				path:     "/api/v0/health"
				timeout:  "2s"
			}
		}

		let ref = {block0: #block0, database: #database, domain: #domain, version: #version}

		task: "servicing-station": tasks.#ServicingStation & {
			#block0:   ref.block0
			#database: ref.database
			#domain:   ref.domain
			#flake:    #flakes.#servicingStation
			#version:  ref.version
		}

		task: "promtail": tasks.#Promtail
	}
}
