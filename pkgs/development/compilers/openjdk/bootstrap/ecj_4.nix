{
  lib,
  stdenv,
  fetchurl,
  fastjar,
  ant_1_8,
  classpath_latest,
  jamvm_2,
  unzip,
  zip,
  ecj_3,
  callPackage,
}:
let
  wrapperScript = callPackage ./builders/ecj-wrapper.nix {
    classpath = classpath_latest;
    jamvm = jamvm_2;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ecj";
  version = "4.2.1";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    # Fetching the jar here allows us to skip building a version of IcedTea, which significantly cuts down on bootstrap time.
    url = "http://archive.eclipse.org/eclipse/downloads/drops4/R-${finalAttrs.version}-201209141800/ecjsrc-${finalAttrs.version}.jar";
    hash = "sha256-0mGyFY9ZhkDxkjgF0um/R+sh2DM/Ths39Z+EetANSPQ=";
  };

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    cd source
    fastjar -xvf ${finalAttrs.src}
    runHook postUnpack
  '';

  preBuild = ''
    declare -a tmpClasspath
    tmpClasspath+=("${jamvm_2}/lib/rt.jar")
    for jarFile in ${ant_1_8}/lib/*.jar; do
      tmpClasspath+=($jarFile)
    done
    export CLASSPATH=$(IFS=':' ; echo "''${tmpClasspath[*]}")

    shopt -s globstar
    substituteInPlace ./**/*.java \
      --replace-quiet "@Override" "" \
      --replace-quiet "java.awt.List" "java.util.List"
    shopt -u globstar

    # Temporary javac wrapper with latest jamvm, classpath, and ecj.
    # Current wrapper only has jamvm 1 and classpath 0.93
    # We'll then put a real javac wrapper in the output with this ecj4 build instead.
    cp ${wrapperScript} ./javac
    substituteInPlace ./javac \
      --replace-fail "@ecjPath@" "${ecj_3}"
  '';

  buildPhase = ''
    runHook preBuild

    # These aren't compileable with our current toolchain, but we don't need them for bootstrap
    rm org/eclipse/jdt/core/JDTCompilerAdapter.java
    rm -rf org/eclipse/jdt/internal/antadapter

    # Make simple manifest
    echo "Manifest-Version: 1.0
    Main-Class: org.eclipse.jdt.internal.compiler.batch.Main
    " > META-INF/MANIFESTS.MF

    ./javac $(find . -name "*.java")

    zip -0 -X ecj-bootstrap.jar META-INF/MANIFESTS.MF
    rm META-INF/MANIFESTS.MF
    zip -r -0 -X ecj-bootstrap.jar .

    runHook postBuild
  '';

  nativeBuildInputs = [
    fastjar
    ecj_3
    jamvm_2
    unzip
    zip
    classpath_latest
  ];

  buildInputs = [
    classpath_latest
  ];

  installPhase = ''
    runHook preInstall
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
