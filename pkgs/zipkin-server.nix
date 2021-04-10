{ stdenv, lib, fetchurl, makeWrapper, jre, coreutils }:
let
  version = "2.23.2";
  PATH = lib.makeBinPath [ jre coreutils ];
in stdenv.mkDerivation {
  pname = "zipkin-server";
  inherit version;

  src = fetchurl {
    url =
      "https://search.maven.org/remotecontent?filepath=io/zipkin/zipkin-server/${version}/zipkin-server-${version}-exec.jar";
    sha256 = "sha256-EwX+2YHfK1pGDed0jYnbyir88RD+dO1OmUAVBpvtons=";
  };

  unpackPhase = ":";

  nativeBuildInputs = [ makeWrapper jre ];

  installPhase = ''
    install -Dm755 $src $out/bin/zipkin-server
    wrapProgram $out/bin/zipkin-server --set PATH ${PATH}
  '';

  meta = with lib; {
    description = "Zipkin distributed tracing system";
    homepage = "https://zipkin.io/";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = [ maintainers.manveru ];
  };
}
