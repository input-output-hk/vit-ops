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
		datacenters: list.MinItems(1) & [...datacenter] | *[ "eu-central-1", "us-east-2", "eu-west-1"]
		#version:    string | *"3.1"

		#flakes: {
			#jormungandr:      string | *"github:input-output-hk/jormungandr/edfe2c2a73de1d6548eaecbfb19b7c32aadbf178#jormungandr-entrypoint"
			#servicingStation: string | *"github:input-output-hk/vit-servicing-station/70c54048d18835cdd34aedcbd3a9365c38eb7304#vit-servicing-station-server"
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
		}
		jobs: _defaultJobs
	}

	"catalyst-fund5": {
		vars: {
			#domain: "servicing-station.\(fqdn)"
			#flakes: #jormungandr: "github:input-output-hk/jormungandr/edfe2c2a73de1d6548eaecbfb19b7c32aadbf178#jormungandr-entrypoint"
		}
		jobs: _defaultJobs
	}

	"catalyst-perf": {
		vars: {
			#domain: "perf-servicing-station.\(fqdn)"
			#flakes: #jormungandr: "github:input-output-hk/jormungandr/c9aa8cd2bfcf20c77a6a59612638a7d7cbb24f38#jormungandr-entrypoint"
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
		}
		jobs: _defaultJobs
	}

	"catalyst-test": {
		jobs: {
			devbox: jobDef.#DevBox & {
				#vitOpsRev: "a2f44c1c8f4259548674c9d284fdb302f3f0dba3"
				#flakes: devBox: "github:input-output-hk/vit-ops?rev=\(#vitOpsRev)#devbox-entrypoint"
			}
			wormhole: jobDef.#Wormhole
		}
	}

	"catalyst-sync": {
		jobs: {
			"db-sync-mainnet": jobDef.#DbSync & {
				#dbSyncNetwork:            "mainnet"
				#dbSyncInstance:           "i-0ba0564889ae9094c"
				#snapshotDomain:           "snapshot-mainnet.\(fqdn)"
				#registrationDomain:       "registration-mainnet.\(fqdn)"
				#registrationVerifyDomain: "registration-verify-mainnet.\(fqdn)"
			}
			"db-sync-testnet": jobDef.#DbSync & {
				#dbSyncNetwork:            "testnet"
				#dbSyncInstance:           "i-002a3025e13ed07ca"
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
