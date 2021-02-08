let Role = ./Role.dhall

in  { Type =
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
