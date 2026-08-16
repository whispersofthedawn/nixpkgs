{
  lib,
  stdenv,
  fetchurl,
  fetchpatch,
  classpath_0_93,
  autoconf,
  automake,
  libtool,
  zip,
  zlib,
  jikes,
  libffi,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jamvm";
  # Last version of jamvm that supports gnu classpath which doesn't require ECJ
  version = "1.5.1";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "mirror://sourceforge/jamvm/jamvm/JamVM%20${finalAttrs.version}/jamvm-${finalAttrs.version}.tar.gz";
    # sha256 = "06lhi03l3b0h48pc7x58bk9my2nrcf1flpmglvys3wyad6yraf36";
    hash = "sha256-ZjiVvWnK86H9pq9e6oJj2Qpf01yo9MMuIhCsQQeIkBo=";
  };

  postUnpack = ''
    rm $sourceRoot/lib/classes.zip
  '';

  patches = [
    ./patches/jamvm_1-fix-buffer-overflow-during-class-loading.patch
    ./patches/jamvm_1-aarch64-support.patch
    ./patches/jamvm_1-armv7-support.patch
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types";

  # Only need to reconfigure for aarch64, as pre-built files do not support it.
  preConfigure = lib.optionalString stdenv.hostPlatform.isAarch64 ''
    autoreconf -vif
  '';

  configureFlags = [
    "--with-classpath-install-dir=${classpath_0_93}"
    "--disable-int-caching"
    "--enable-runtime-reloc-checks"
    "--enable-ffi"
  ];

  nativeBuildInputs = [
    zip
    jikes
  ]
  ++ lib.optionals stdenv.hostPlatform.isAarch64 [
    # Additional packages needed for autoreconf in above `preConfigure`
    autoconf
    automake
    libtool
  ];

  buildInputs = [
    classpath_0_93
    zlib
    libffi
  ];

  meta = {
    description = "Small Java Virtual Machine";
    homepage = "https://jamvm.sourceforge.net";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };
})
