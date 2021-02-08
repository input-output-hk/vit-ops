let Job = ./Job.dhall

in  { Type =
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
      , jobs = [] : List Job.Type
      }
    }
