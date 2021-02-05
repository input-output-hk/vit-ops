let fqdn = "vit.iohk.io"

let Role = < leader | follower >

let Job =
      { Type =
          { template : Text
          , name : Text
          , requiredPeerCount : Optional Natural
          , index : Optional Natural
          , role : Optional Role
          }
      , default =
        { requiredPeerCount = None Natural
        , index = None Natural
        , role = None Role
        }
      }

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

let jobs =
      { leader-0 = makeNode 0 Role.leader
      , leader-1 = makeNode 1 Role.leader
      , leader-2 = makeNode 2 Role.leader
      , follower-0 = makeNode 0 Role.follower
      , servicing-station = Job::{
        , name = "servicing-station"
        , template = "./jobs/servicing-station.hcl"
        }
      , db-sync = Job::{ name = "db-sync", template = "./jobs/db-sync.hcl" }
      }

let Namespace =
      { Type =
          { datacenters : List Text
          , vitOpsRev : Text
          , dbSyncRev : Text
          , domain : Text
          , jobs : List Job.Type
          , dbSyncInstance : Text
          }
      , default =
        { datacenters = [ "eu-central-1", "us-east-2" ]
        , vitOpsRev = "976053383c8933a36340715a90c08362136e72e7"
        , dbSyncRev = "123312bccc171e2d9fc8e437abb4fd69b0169459"
        , dbSyncInstance = Text
        , jobs =
          [ jobs.leader-0
          , jobs.leader-1
          , jobs.leader-2
          , jobs.follower-0
          , jobs.servicing-station
          ]
        }
      }

let namespaces =
      { catalyst-dryrun = Namespace::{
        , domain = "dryrun-servicing-station.${fqdn}"
        , dbSyncInstance = "i-0205f47513cff5c29"
        }
      , catalyst-fund3 = Namespace::{
        , domain = "servicing-station.${fqdn}"
        , dbSyncInstance = "i-07bd940275dceaec0"
        , jobs = Namespace.default.jobs # [ jobs.db-sync ]
        }
      }

in  namespaces
