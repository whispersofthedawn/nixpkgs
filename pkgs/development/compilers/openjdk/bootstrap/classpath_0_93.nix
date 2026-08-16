{
  lib,
  stdenv,
  jikes,
  fastjar,
  libtool,
  pkg-config,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "classpath";
  # Last version of GNU Classpath that supports being built with jikes.
  version = "0.93";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "mirror://gnu/classpath/classpath-${finalAttrs.version}.tar.gz";
    hash = "sha256-3y0JNhKr0j/mfpQJ2JuyqOebFmT+Ky2kDhyO1pPjKUU=";
  };

  # patches from guix
  patches = [
    ./patches/classpath-aarch64-support.patch
    ./patches/classpath-miscompilation.patch
  ];

  configureFlags = [
    "JAVAC=${jikes}/bin/jikes"
    "--disable-Werror"
    "--disable-gmp"
    "--disable-gtk-peer"
    "--disable-gconf-peer"
    "--disable-plugin"
    "--disable-dssi"
    "--disable-alsa"
    "--disable-gjdoc"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error=implicit-function-declaration";

  nativeBuildInputs = [
    jikes
    fastjar
    libtool
    pkg-config
  ];

  postInstall = ''
    make install-data
  '';

  meta = {
    description = "Essential libraries for Java";
    homepage = "https://www.gnu.org/software/classpath";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
  };
})
