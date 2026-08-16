{
  lib,
  stdenv,
  fetchgit,
  fastjar,
  libtool,
  pkg-config,
  ecj_3,
  jamvm_1,
  classpath_0_99,
  autoreconfHook,
  jdk5_jamvm_classpath,
  texinfo,
  gettext,
}:
stdenv.mkDerivation {
  pname = "classpath";
  version = "0-unstable-2016-03-18";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchgit {
    url = "https://git.savannah.gnu.org/git/classpath.git";
    rev = "e7c13ee0cf2005206fbec0eca677f8cf66d5a103";
    hash = "sha256-hEdXkMAcQDGK7uylusK48xk2Z1Ai6PFuFWJwbg7nWew=";
  };

  patches = [
    ./patches/classpath-aarch64-support.patch
  ];

  env = {
    JAVAC_MEM_OPT = "-J-Xms512M -J-Xmx768M";
  };

  configureFlags = [
    "--with-ecj-jar=${ecj_3}/share/java/ecj-bootstrap.jar"
    "--with-javac=${ecj_3}/bin/javac"
    "JAVA=${jamvm_1}/bin/jamvm"
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

  preBuild = ''
    shopt -s globstar
    substituteInPlace java/**/*.java \
      --replace-quiet "@Override" ""
    shopt -u globstar
  '';

  nativeBuildInputs = [
    libtool
    pkg-config
    classpath_0_99
    autoreconfHook
    jdk5_jamvm_classpath
    ecj_3
    fastjar
    jamvm_1
    texinfo
    gettext
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
}
