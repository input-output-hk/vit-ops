{ runCommand, coreutils }:
runCommand "foo" { buildInputs = [ cue coreutils ]; } ''
  cat ${./deploy.cue} > $out
''
