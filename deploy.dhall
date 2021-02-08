let Role = ./dhall/Role.dhall

let Job = ./dhall/Job.dhall

let Namespace = ./dhall/Namespace.dhall

let showRole =
      λ(role : Role) → merge { leader = "leader", follower = "follower" } role

let requiredPeerCountForRole =
      λ(role : Role) →
      λ(index : Natural) →
        merge { leader = Some index, follower = Some 3 } role

let makeNode =
      λ(index : Natural) →
      λ(role : Role) →
        Job::{
        , name = "${showRole role}-${Natural/show index}"
        , template = "./jobs/jormungandr.hcl"
        , requiredPeerCount = requiredPeerCountForRole role index
        , index = Some index
        , role = Some role
        }

let leader-0 = makeNode 0 Role.leader

let leader-1 = makeNode 1 Role.leader

let leader-2 = makeNode 2 Role.leader

let follower-0 = makeNode 0 Role.follower

let servicing-station =
      Job::{
      , name = "servicing-station"
      , template = "./jobs/servicing-station.hcl"
      }

let db-sync = Job::{ name = "db-sync", template = "./jobs/db-sync.hcl" }

let defaultJobs =
      [ leader-0, leader-1, leader-2, follower-0, servicing-station ]

let fqdn = "vit.iohk.io"

let namespaces =
      { catalyst-dryrun = Namespace::{
        , domain = "dryrun-servicing-station.${fqdn}"
        , dbSyncInstance = "i-0205f47513cff5c29"
        , jobs = defaultJobs
        }
      , catalyst-fund3 = Namespace::{
        , domain = "servicing-station.${fqdn}"
        , dbSyncInstance = "i-07bd940275dceaec0"
        , jobs = [ db-sync ]
        }
      }

in  namespaces
