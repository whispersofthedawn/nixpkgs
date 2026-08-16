{
  lib,
  stdenv,
  fetchurl,
  fastjar,
  libtool,
  pkg-config,
  ecj_3,
  jamvm_1,
  classpath_0_93,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "classpath";
  version = "0.99";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "mirror://gnu/classpath/classpath-${finalAttrs.version}.tar.gz";
    hash = "sha256-+Skpf4rpthOhoWfiMVZoYYkyYGUdkTrZtsEZM4lf7Mg=";
  };

  patches = [
    ./patches/classpath-aarch64-support.patch
  ];

  configureFlags = [
    "JAVAC=${ecj_3}/bin/javac"
    "JAVA=${jamvm_1}/bin/jamvm"
    "--with-ecj-jar=${ecj_3}/share/java/ecj-bootstrap.jar"
    "GCJ_JAVAC_TRUE=no"
    "ac_cv_prog_java_works=yes"
    "--disable-Werror"
    "--disable-gmp"
    "--disable-gtk-peer"
    "--disable-gconf-peer"
    "--disable-plugin"
    "--disable-dssi"
    "--disable-alsa"
    "--disable-gjdoc"
  ];

  nativeBuildInputs = [
    fastjar
    libtool
    pkg-config
    classpath_0_93
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
