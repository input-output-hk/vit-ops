package bitte

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
	jobDef "github.com/input-output-hk/vit-ops/pkg/jobs:jobs"
	"list"
)

let fqdn = "vit.iohk.io"

_defaultJobs: {
	"leader-0":          jobDef.#Jormungandr & {#role: "leader", #index:   0}
	"leader-1":          jobDef.#Jormungandr & {#role: "leader", #index:   1}
	"leader-2":          jobDef.#Jormungandr & {#role: "leader", #index:   2}
	"follower-0":        jobDef.#Jormungandr & {#role: "follower", #index: 0}
	"servicing-station": jobDef.#ServicingStation
}

#vitOpsRev: "55759981d7e693b0304ecf2d4bace0dc068caa6d"

#flakes: {
	devbox: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#devbox-entrypoint"
}

artifacts: [string]: [string]: {url: string, checksum: string}

Namespace: [Name=_]: {
	vars: {
		let hex = "[0-9a-f]"
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"

		namespace:   Name
		#block0:     artifacts[Name].block0
		#database:   artifacts[Name].database
		#domain:     string
		#fqdn:       fqdn
		#vitOpsRev:  =~"^\(hex){40}$" | *"55759981d7e693b0304ecf2d4bace0dc068caa6d"
		#dbSyncRev:  =~"^\(hex){40}$" | *"af6f4d31d137388aa59bae10c2fa79c219ce433d"
		datacenters: list.MinItems(1) | [...datacenter] | *[ "eu-central-1", "us-east-2", "eu-west-1"]
		#version: string | *"2.0"

		#flakes: {
			#jormungandr:      string | *"github:input-output-hk/vit-ops?rev=c9251b4f3f0b34a22e3968bf28d5a049da120f8f#jormungandr-entrypoint"
			#servicingStation: string | *"github:input-output-hk/vit-servicing-station/160f09c7a26fe31628b7573e8c326e3d90f1ab47#vit-servicing-station-server"
		}
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: Namespace

#namespaces: {
	"catalyst-dryrun": {
		vars: {
			#domain: "dryrun-servicing-station.\(fqdn)",
			#flakes: {
			   #servicingStation: "github:input-output-hk/vit-servicing-station/cbbb79a3e8edcb74d59ed532eb961a4022605e65#vit-servicing-station-server"
			}
		}
		jobs: _defaultJobs
	}

	"catalyst-fund3": {
		vars: {
			#domain: "servicing-station.\(fqdn)"
		}
		jobs: _defaultJobs
	}

	"catalyst-perf": {
		vars: {
			#domain: "perf-servicing-station.\(fqdn)"
		}
		jobs: _defaultJobs
	}

	"catalyst-test": {
		jobs: {
			devbox: jobDef.#DevBox & {
				#vitOpsRev: "a2f44c1c8f4259548674c9d284fdb302f3f0dba3"
				#flakes: devBox: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#devbox-entrypoint"
			}
		}
	}

	"catalyst-sync": {
		jobs: {
			"db-sync-mainnet": jobDef.#DbSync & {
				#dbSyncNetwork:  "mainnet"
				#dbSyncInstance: "i-0425dd53d4b0f8939"
				#domain:         "snapshot-mainnet.\(fqdn)"
			}
			"db-sync-testnet": jobDef.#DbSync & {
				#dbSyncNetwork:  "testnet"
				#dbSyncInstance: "i-0ce9a9084a83348e6"
				#domain:         "snapshot-testnet.\(fqdn)"
			}
		}
	}
}

for nsName, nsValue in #namespaces {
	rendered: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": Job: types.#toJson & {
				#jobName: jName
				#job:     jValue & nsValue.vars
			}
		}
	}
}

for nsName, nsValue in #namespaces {
	// output is alphabetical, so better errors show at the end.
	zchecks: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": jValue & nsValue.vars
		}
	}
}
