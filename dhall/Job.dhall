let Role = ./Role.dhall
let Map = https://prelude.dhall-lang.org/Map/Type
let VarMap = Map Text Text

in  { Type =
        { template : Text
        , name : Text
        , requiredPeerCount : Optional Natural
        , index : Optional Natural
        , role : Optional Role
        , vars : VarMap
        }
    , default =
      { requiredPeerCount = None Natural
      , index = None Natural
      , role = None Role
      , vars = [] : VarMap
      }
    }
