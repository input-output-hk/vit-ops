{ pkgs, ... }: { services.nomad.pluginDir = "${pkgs.nomad-driver-nspawn}/bin"; }
