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
      { datacenters = [ "eu-central-1", "us-east-2", "eu-west-1" ]
      , vitOpsRev = "c9251b4f3f0b34a22e3968bf28d5a049da120f8f"
      , dbSyncRev = "123312bccc171e2d9fc8e437abb4fd69b0169459"
      , dbSyncInstance = Text
      , jobs = [] : List Job.Type
      }
    }
