package bitte

import (
	"github.com/input-output-hk/vit-ops/pkg/schemas/nomad:types"
)

let fqdn = "vit.iohk.io"

let Namespace = {
	vars: {
		let hex = "[0-9a-f]"
		let datacenter = "eu-central-1" | "us-east-2" | "eu-west-1"

		namespace:       string
		#domain:         string
		#dbSyncInstance: =~"^i-\(hex){17}$"
		#vitOpsRev:      =~"^\(hex){40}$" | *"c9251b4f3f0b34a22e3968bf28d5a049da120f8f"
		#dbSyncRev:      =~"^\(hex){40}$" | *"123312bccc171e2d9fc8e437abb4fd69b0169459"
		#dbSyncNetwork:  "testnet" | "mainnet"
		datacenters:     [...datacenter] | *[ "eu-central-1", "us-east-2", "eu-west-1"]
	}
	jobs: [string]: types.#stanza.job
}

#namespaces: [Name=_]: Namespace & {vars: namespace: Name}

#namespaces: {
	"catalyst-dryrun": {
		vars: {
			#domain:         "dryrun-servicing-station.\(fqdn)"
			#dbSyncInstance: "i-0205f47513cff5c29"
			#dbSyncNetwork:  "testnet"
		}
		jobs: {
			"leader-0":          #Jormungandr & {#role: "leader", #index:   0}
			"leader-1":          #Jormungandr & {#role: "leader", #index:   1}
			"leader-2":          #Jormungandr & {#role: "leader", #index:   2}
			"follower-0":        #Jormungandr & {#role: "follower", #index: 0}
			"servicing-station": #ServicingStation
			"db-sync":           #DbSync
		}
	}

	"catalyst-fund3": {
		vars: {
			#domain:         "servicing-station.\(fqdn)"
			#dbSyncInstance: "i-03d242d53cb137764"
			#dbSyncNetwork:  "mainnet"
		}
		jobs: {
			"leader-0":          #Jormungandr & {#role: "leader", #index:   0}
			"leader-0":          #Jormungandr & {#role: "leader", #index:   0}
			"leader-1":          #Jormungandr & {#role: "leader", #index:   1}
			"leader-2":          #Jormungandr & {#role: "leader", #index:   2}
			"follower-0":        #Jormungandr & {#role: "follower", #index: 0}
			"servicing-station": #ServicingStation
			"db-sync":           #DbSync
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
