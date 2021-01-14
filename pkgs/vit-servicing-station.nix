{ symlinkJoin, debugUtils, vit-servicing-station, ... }:
symlinkJoin {
  name = "vit-servicing-station-env";
  paths = debugUtils ++ [ vit-servicing-station ];
}
