package bitte

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

let fqdn = "vit.iohk.io"

let Namespace = {
	vars: {
		let hex = "[0-9a-f]"
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"

		namespace:   string
		#domain:     string
		#vitOpsRev:  =~"^\(hex){40}$" | *"c9251b4f3f0b34a22e3968bf28d5a049da120f8f"
		#dbSyncRev:  =~"^\(hex){40}$" | *"1518c0ee4eaf21caff207b1fc09ff047eda50ee0"
		datacenters: [...datacenter] | *[ "eu-central-1", "us-east-2", "eu-west-1"]
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: [Name=_]: Namespace & {vars: namespace: Name}

#namespaces: {
	"catalyst-dryrun": {
		vars: {
			#domain: "dryrun-servicing-station.\(fqdn)"
		}
		jobs: {
			"leader-0":          #Jormungandr & {#role: "leader", #index:   0}
			"leader-1":          #Jormungandr & {#role: "leader", #index:   1}
			"leader-2":          #Jormungandr & {#role: "leader", #index:   2}
			"follower-0":        #Jormungandr & {#role: "follower", #index: 0}
			"servicing-station": #ServicingStation
		}
	}

	"catalyst-fund3": {
		vars: {
			#domain: "servicing-station.\(fqdn)"
		}
		jobs: {
			"leader-0":          #Jormungandr & {#role: "leader", #index:   0}
			"leader-1":          #Jormungandr & {#role: "leader", #index:   1}
			"leader-2":          #Jormungandr & {#role: "leader", #index:   2}
			"follower-0":        #Jormungandr & {#role: "follower", #index: 0}
			"servicing-station": #ServicingStation
		}
	}

	// i-03d242d53cb137764 -> i-0425dd53d4b0f8939
	// mainnet => i-0425dd53d4b0f8939 | c5.4xlarge | eu-west-1a | 10.32.121.96 | 34.245.54.60
	// testnet => i-0ce9a9084a83348e6 | c5.4xlarge | eu-west-1a | 10.32.84.131 | 34.245.86.116
	// i-0205f47513cff5c29 -> i-0ce9a9084a83348e6

	"catalyst-sync": {
		jobs: {
			"db-sync-mainnet": #DbSync & {#dbSyncNetwork: "mainnet", #dbSyncInstance: "i-0425dd53d4b0f8939"}
			"db-sync-testnet": #DbSync & {#dbSyncNetwork: "testnet", #dbSyncInstance: "i-0ce9a9084a83348e6"}
		}
	}
}

for nsName, nsValue in #namespaces {
	rendered: "\(nsName)": {
		for jName, jValue in nsValue.jobs {
			"\(jName)": Job: types.toJson & {
				#jobName: jName
				#job:     jValue & nsValue.vars
			}
		}
	}
}
