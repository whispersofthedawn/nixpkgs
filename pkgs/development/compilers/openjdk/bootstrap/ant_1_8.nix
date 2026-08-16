{
  lib,
  stdenv,
  fetchurl,
  jikes,
  jamvm_1,
  unzip,
  zip,
  writableTmpDirAsHomeHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ant";
  # The ant 1.8.x series is the last to support usage with jikes
  version = "1.8.4";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    # While we could use `mirror://apache`, we don't since this is only available on the archive server.
    url = "https://archive.apache.org/dist/ant/source/apache-ant-${finalAttrs.version}-src.tar.bz2";
    hash = "sha256-XeZfe6P2fkNv//zcCnP1kdEAbp+0GvhjLB8fhNSj4LE=";
  };

  postPatch = ''
    sed 's/^\("''${JAVACMD}" \)/\1-Xnocompact -Xnoinlining /' -i bootstrap.sh
    sed 's/depends="jars,test-jar"/depends="jars"/g' -i build.xml
  '';

  env = {
    JAVA_HOME = jamvm_1;
    JAVACMD = "${jamvm_1}/bin/jamvm";
    JAVAC = "${jikes}/bin/jikes";
    CLASSPATH = "${jamvm_1}/lib/rt.jar";
    ANT_OPTS = "-Dbuild.compiler=jikes";
    BOOTJAVAC_OPTS = "-nowarn";
  };

  nativeBuildInputs = [
    jikes
    jamvm_1
    unzip
    zip
    writableTmpDirAsHomeHook
  ];

  buildPhase = ''
    mkdir -p $out
    touch $HOME/.ant.properties
    bash -x bootstrap.sh -Ddist.dir=$out
  '';

  meta = {
    description = "Build tool for Java";
    homepage = "https://ant.apache.org";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
})
