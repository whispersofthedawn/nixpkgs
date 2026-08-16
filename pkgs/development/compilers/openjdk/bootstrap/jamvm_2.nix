{
  fetchurl,
  stdenv,
  lib,
  classpath_latest,
  ecj_3,
  libffi,
  zip,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jamvm";
  version = "2.0.0";

  src = fetchurl {
    url = "mirror://sourceforge/jamvm/jamvm/JamVM%20${finalAttrs.version}/jamvm-${finalAttrs.version}.tar.gz";
    hash = "sha256-dkKOlt8K6d2WTHp8dMHpqDfi8xLDnpo1f6gXj37/gNo=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  patches = [
    ./patches/jamvm_2-aarch64-support.patch
    ./patches/jamvm_2-disable-branch-patching.patch
    ./patches/jamvm_2-opcode-guard.patch
  ];

  postPatch = ''
    rm src/classlib/gnuclasspath/lib/classes.zip
  '';

  configureFlags = [
    "--with-classpath-install-dir=${classpath_latest}"
  ];

  nativeBuildInputs = [
    ecj_3
    zip
    classpath_latest
  ];

  buildInputs = [
    classpath_latest
    libffi
    zlib
  ];

  meta = {
    description = "Small Java Virtual Machine";
    homepage = "https://jamvm.sourceforge.net";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };
})
