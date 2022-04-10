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
	wormhole:            jobDef.#Wormhole
}

#vitOpsRev: "5174b396ab0f58a096809f5c51279a19b9ca08d0"

#flakes: {
	devbox:             "github:input-output-hk/vit-ops?rev=8acac60455b33432d9f64fce28c06d7cbc65b0df#devbox-entrypoint"
	dbSyncTestnet:      "github:input-output-hk/vit-ops?rev=4aaa6c7d2166e87a5789ac62073a18f1e551d7ab#testnet/db-sync"
	dbSyncMainnet:      "github:input-output-hk/vit-ops?rev=4aaa6c7d2166e87a5789ac62073a18f1e551d7ab#mainnet/db-sync"
	postgres:           "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#postgres-entrypoint"
	cardanoNodeTestnet: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#testnet/node"
	cardanoNodeMainnet: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#mainnet/node"
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
		#vitOpsRev:  =~"^\(hex){40}$" | *"5174b396ab0f58a096809f5c51279a19b9ca08d0"
		#dbSyncRev:  =~"^\(hex){40}$" | *"af6f4d31d137388aa59bae10c2fa79c219ce433d"
		datacenters: list.MinItems(1) & [...datacenter] | *[ "eu-central-1", "us-east-2", "eu-west-1"]
		#version:    string | *"3.6"

		#flakes: {
			#jormungandr:      string | *"github:input-output-hk/jormungandr/?rev=9e3c8b7e949798c66ed419d9f18481eb0a52b23a#jormungandr-entrypoint"
			#servicingStation: string | *"github:input-output-hk/vit-servicing-station/catalyst-fund7#vit-servicing-station-server"
		}

		#rateLimit: {
			average: uint | *100
			burst:   uint | *250
			period:  types.#durationType | *"1m"
		}
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: Namespace

#namespaces: {
	"catalyst-dryrun": {
		vars: {
			#domain: "dryrun-servicing-station.\(fqdn)"
			#flakes: {
				#jormungandr: "github:input-output-hk/jormungandr/catalyst-fund8#jormungandr-entrypoint"
				#servicingStation: "github:input-output-hk/vit-servicing-station/catalyst-fund8#vit-servicing-station-server"
			}
		}
		jobs: _defaultJobs
	}

	"catalyst-fund7": {
		vars: {
			#domain: "servicing-station.\(fqdn)"
		}
		jobs: _defaultJobs
	}

	"catalyst-perf": {
		vars: {
			#domain: "perf-servicing-station.\(fqdn)"
			#rateLimit: {
				average: 100000
				burst:   200000
				period:  "1m"
			}
		}
		jobs: _defaultJobs
	}

	"catalyst-signoff": {
		vars: {
			#domain: "signoff-servicing-station.\(fqdn)"
			#flakes: #jormungandr: "github:input-output-hk/jormungandr/master#jormungandr-entrypoint"
		}
		jobs: _defaultJobs
	}

	"catalyst-test": {
		jobs: {
			let ref = {
				cardanoNodeFlake: #flakes.cardanoNodeTestnet
			}
			devbox: jobDef.#DevBox & {
				#vitOpsRev: "a2f44c1c8f4259548674c9d284fdb302f3f0dba3"
				#flakes: devBox: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#devbox-entrypoint"
				#cardanoNodeFlake: ref.cardanoNodeFlake
			}
			wormhole: jobDef.#Wormhole
		}
	}

	"catalyst-sync": {
		jobs: {
			"db-sync-mainnet": jobDef.#DbSync & {
				#dbSyncNetwork:            "mainnet"
				#dbSyncInstance:           "i-0cd55c9eb12e663e6"
				#dbSyncFlake:              #flakes.dbSyncMainnet
				#cardanoNodeFlake:         #flakes.cardanoNodeMainnet
				#postgresFlake:            #flakes.postgres
				#snapshotDomain:           "snapshot-mainnet.\(fqdn)"
				#registrationDomain:       "registration-mainnet.\(fqdn)"
				#registrationVerifyDomain: "registration-verify-mainnet.\(fqdn)"
			}
			"db-sync-testnet": jobDef.#DbSync & {
				#dbSyncNetwork:            "testnet"
				#dbSyncInstance:           "i-0052b9735a0abf850"
				#dbSyncFlake:              #flakes.dbSyncTestnet
				#cardanoNodeFlake:         #flakes.cardanoNodeTestnet
				#postgresFlake:            #flakes.postgres
				#snapshotDomain:           "snapshot-testnet.\(fqdn)"
				#registrationDomain:       "registration-testnet.\(fqdn)"
				#registrationVerifyDomain: "registration-verify-testnet.\(fqdn)"
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
