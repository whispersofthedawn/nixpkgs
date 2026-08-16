{
  lib,
  stdenv,
  fetchzip,
  jamvm_1,
  classpath_0_93,
  jikes,
  fastjar,
  ant_1_8,
  callPackage,
}:
let
  wrapperScript = callPackage ./builders/ecj-wrapper.nix {
    classpath = classpath_0_93;
    jamvm = jamvm_1;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ecj";
  version = "3.2.2";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchzip {
    stripRoot = false;
    url = "http://archive.eclipse.org/eclipse/downloads/drops/R-${finalAttrs.version}-200702121330/ecjsrc.zip";
    hash = "sha256-Hdt/yYaZOQOV8bKIQz+xouX8iPr2eV3z6zh9R376I3o=";
  };

  env.CLASSPATH = "${jamvm_1}/lib/rt.jar:${
    lib.concatStringsSep ":" (
      map (j: "${ant_1_8}/lib/${j}") [
        "ant-antlr.jar"
        "ant-apache-bcel.jar"
        "ant-apache-bsf.jar"
        "ant-apache-log4j.jar"
        "ant-apache-oro.jar"
        "ant-apache-regexp.jar"
        "ant-apache-resolver.jar"
        "ant-apache-xalan2.jar"
        "ant-commons-logging.jar"
        "ant-commons-net.jar"
        "ant-jai.jar"
        "ant-javamail.jar"
        "ant-jdepend.jar"
        "ant-jmf.jar"
        "ant-jsch.jar"
        "ant-junit.jar"
        "ant-junit4.jar"
        "ant-launcher.jar"
        "ant-netrexx.jar"
        "ant-swing.jar"
        "ant.jar"
      ]
    )
  }";

  nativeBuildInputs = [
    jikes
    fastjar
  ];

  buildInputs = [
    ant_1_8
    classpath_0_93
  ];

  buildPhase = ''
    echo > manifest "Manifest-Version: 1.0
    Main-Class: org.eclipse.jdt.internal.compiler.batch.Main
    "
    jikes $(find . -name "*.java")
    fastjar cvfm ecj-bootstrap.jar manifest .
  '';

  installPhase = ''
    mkdir -p $out/share/java $out/bin
    cp ecj-bootstrap.jar $out/share/java
    cp ${wrapperScript} $out/bin/javac
    substituteInPlace $out/bin/javac \
      --replace-fail "@ecjPath@" "$out"
  '';

  passthru.javacWrapper = wrapperScript;

  meta = {
    description = "Eclipse Java development tools core batch compiler";
    homepage = "https://eclipse.org";
    license = lib.licenses.epl10;
    platforms = lib.platforms.unix;
  };
})
