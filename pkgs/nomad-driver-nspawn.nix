{ stdenv, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "nomad-driver-nspawn";
  version = "0.6.0";
  goPackagePath = "github.com/JanMa/${pname}";
  src = fetchFromGitHub {
    owner = "JanMa";
    repo = "nomad-driver-nspawn";
    rev = "a4ea4e5748b0825e3101ed89e0a01fde7dbfefea";
    sha256 = "r79eK4P6Z730bPZaD2FNW4K401CpiBgoH1gWrlOQg88=";
    fetchSubmodules = true;
  };
  subPackages = [ "." ];
  vendorSha256 = null;
  CGO_ENABLED = "0";
  GOOS = "linux";
  buildFlagsArray = ''
    -ldflags= -s -w -extldflags "-static" -X github.com/JanMa/${pname}/nspawn.pluginVersion=${version}
  '';
}

