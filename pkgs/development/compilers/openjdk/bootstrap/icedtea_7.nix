{
  lib,
  stdenv,
  fetchzip,
  fetchurl,
  # System dependencies - libraries
  alsa-lib,
  cups,
  freetype,
  fontconfig,
  giflib,
  krb5,
  lcms2,
  libjpeg_turbo,
  libpng,
  libx11,
  libxcomposite,
  libxi,
  libxinerama,
  libxrender,
  libxt,
  libxtst,
  pcsclite,
  which,
  zlib,
  # System dependencies - tools
  # keep-sorted start
  attr,
  autoconf,
  automake,
  coreutils,
  cpio,
  fastjar,
  gawk,
  gnugrep,
  gnused,
  hostname,
  libtool,
  libxslt,
  perl,
  pkg-config,
  procps,
  unzip,
  wget,
  zip,
  # keep-sorted end
  # Bootstrap dependencies
  # keep-sorted start
  ant_1_8,
  classpath_latest,
  ecj_4,
  jamvm_2,
  # keep-sorted end
}:
let
  version = "2.6.28";
  fetchdrop =
    name: hash:
    fetchurl {
      name = "${name}-drop-src";
      url = "http://icedtea.classpath.org/download/drops/icedtea7/${version}/${name}.tar.bz2";
      inherit hash;
    };

  drops = {
    openjdk-src = fetchdrop "openjdk" "sha256-eOXon8UQKAQB4ifZgKvjDUnqUIw+7FNwNUgf0ho7LDI=";
    jdk-src = fetchdrop "jdk" "sha256-CBImmx+KOITSwmWdlE4g/PsFTZFqVxLkBdelT6srUWc=";
    corba-src = fetchdrop "corba" "sha256-sAIkBiG+QEeD7QEX/gUlUrTvhq2t5PLIVhzO5g7LqEU=";
    jaxp-src = fetchdrop "jaxp" "sha256-/ZPmWkaSWTwhAJY74sddaXoyulHuLALH59zMUk37F4g=";
    jaxws-src = fetchdrop "jaxws" "sha256-I7LGIXUmCPA/i2F1PhmyEkbdWFBki836SfLGuM2TCi8=";
    langtools-src = fetchdrop "langtools" "sha256-JHmdXr6/seMW+UNNsdtaNgrHyG5Xg85YaTU2+Xigqkc=";
    hotspot-src = fetchdrop "hotspot" "sha256-tol81d1wryAebKEHsnWSF/ksogdkPFEo3MqeCjOzTPw=";
  };

  jamvm_src = fetchurl {
    url = "https://icedtea.classpath.org/download/drops/jamvm/jamvm-ec18fb9e49e62dce16c5094ef1527eed619463aa.tar.gz";
    hash = "sha256-MYECZmZsI4IpQqrGKngBnCxFieHF7kgynL9CZS1EN7w=";
  };

  classpathTools = "${classpath_latest}/share/classpath/tools.zip";
  rtJar = "${jamvm_2}/lib/rt.jar";
in
stdenv.mkDerivation {
  pname = "icedtea";
  inherit version;

  outputs = [
    "out"
  ];

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchzip {
    url = "https://icedtea.classpath.org/download/source/icedtea-${version}.tar.xz";
    hash = "sha256-12azVcT5w4PFT0Nq+iB4Q/nWlKFauqOohdS39cHxiIw=";
  };

  postUnpack =
    let
      unpackDrop =
        comp:
        let
          compsrc = drops."${comp}-src";
        in
        ''
          echo "unpacking ${comp}"
          mkdir ${comp}
          tar xf ${compsrc} --strip-components=1 -C ${comp}
        '';
      defsLinux = lib.concatStringsSep " " [
        "-fno-strict-aliasing"
        "-fcommon"
        "-Wno-error=implicit-function-declaration"
        "-Wno-error=implicit-int"
        "-Wno-error=incompatible-pointer-types"
        "-Wno-error=int-conversion"
        # Does not build with c23, which is GCC 15+'s default.
        "-std=gnu17"

      ];

      mawtX11Path =
        let
          mkPath = pack: "${pack}/include/X11/extensions";
        in
        lib.concatStringsSep " " [
          (mkPath libxrender)
          "-I"
          (mkPath libxtst)
          "-I"
          (mkPath libxinerama)
        ];
    in
    ''
      pushd source
      # Unpack all drops to the correct directory
      mkdir openjdk-src
      tar xf ${drops.openjdk-src} --strip-components=1 -C openjdk-src
      pushd openjdk-src
      ${unpackDrop "jdk"}
      ${unpackDrop "corba"}
      ${unpackDrop "jaxp"}
      ${unpackDrop "jaxws"}
      ${unpackDrop "langtools"}
      ${unpackDrop "hotspot"}

      # misc patches
      pushd hotspot
      patch -p1 -i ${./patches/icedtea_7-hotspot-pointer-comparison.patch}
      popd
      pushd jdk
      patch -p1 -i ${./patches/icedtea_7-jdk-currency-time-bomb.patch}
      popd

      popd
      # Fix distribution ID and use jamvm's runtime
      substituteInPlace "Makefile.in" \
        --replace-fail 'DISTRIBUTION_ID="$(DIST_ID)"' 'DISTRIBUTION_ID="nix"' \
        --replace-fail '$(SYSTEM_JDK_DIR)/jre/lib/rt.jar' '${rtJar}'

      # Patch a bit of bitrot
      # We have newer freetype
      substituteInPlace "patches/boot/revert-6973616.patch" "openjdk-src/jdk/make/common/shared/Defs-versions.gmk" \
        --replace-fail "REQUIRED_FREETYPE_VERSION = 2.2.1" "REQUIRED_FREETYPE_VERSION = 2.10.1"
      # Provided by libc instead of the `attr` library
      substituteInPlace "configure" "openjdk-src/jdk/src/solaris/native/sun/nio/fs/LinuxNativeDispatcher.c" \
        --replace-fail "attr/xattr.h" "sys/xattr.h"

      # misc fixes to openjdk
      pushd openjdk-src

      substituteInPlace "jdk/make/common/Defs-linux.gmk" \
        --replace-fail "CFLAGS_COMMON   = -fno-strict-aliasing" \
          "CFLAGS_COMMON   = ${defsLinux}"

      substituteInPlace jdk/src/solaris/native/java/net/Plain{,Datagram}SocketImpl.c \
        --replace-fail "sys/sysctl.h" "linux/sysctl.h"

      substituteInPlace "hotspot/make/linux/makefiles/gcc.make" \
        --replace-fail "OPT_CFLAGS/NOOPT=-O0" "OPT_CFLAGS/NOOPT=-O0
      OPT_CFLAGS/dump.o += -O0"

      substituteInPlace "jdk/make/sun/awt/mawt.gmk" \
        --replace-fail '$(firstword $(wildcard $(OPENWIN_HOME)/include/X11/extensions) \' '${mawtX11Path}' \
        --replace-fail '$(wildcard /usr/include/X11/extensions))' ""

      popd

      # Patch paths
      pushd openjdk-src

      substituteInPlace "hotspot/make/linux/makefiles/buildtree.make" \
        --replace-fail "/bin/sh" $SHELL

      substituteInPlace "jdk/make/common/shared/Sanity.gmk" \
        --replace-fail "ALSA_INCLUDE=/usr/include/alsa/version.h" "ALSA_INCLUDE=${alsa-lib.dev}/include/alsa/version.h"

      # Last one doesn't match in corba but does in jdk
      substituteInPlace "jdk/make/common/shared/Defs-linux.gmk" "corba/make/common/shared/Defs-linux.gmk" \
        --replace-fail "UNIXCOMMAND_PATH  = /bin" "UNIXCOMMAND_PATH = ${coreutils}/bin" \
        --replace-fail "USRBIN_PATH  = /usr/bin" "USRBIN_PATH = ${coreutils}/bin" \
        --replace-fail "DEVTOOLS_PATH =/usr/bin" "DEVTOOLS_PATH =${coreutils}/bin" \
        --replace-warn "COMPILER_PATH  =/usr/bin" "COMPILER_PATH =${stdenv.cc}/bin"

      # Some only match in one or the other, those warn and others error
      substituteInPlace "jdk/make/common/shared/Defs-utils.gmk" "corba/make/common/shared/Defs-utils.gmk" \
        --replace-fail 'UTILS_COMMAND_PATH=$(UNIXCOMMAND_PATH)' 'UTILS_COMMAND_PATH=${coreutils}/bin/' \
        --replace-fail 'UTILS_USR_BIN_PATH=$(USRBIN_PATH)' 'UTILS_USR_BIN_PATH=${coreutils}/bin/' \
        --replace-fail 'UTILS_CCS_BIN_PATH=$(USRBIN_PATH)' 'UTILS_CCS_BIN_PATH=${stdenv.cc}/bin/' \
        --replace-fail 'UTILS_DEVTOOL_PATH=$(USRBIN_PATH)' 'UTILS_DEVTOOL_PATH=${coreutils}/bin/' \
        --replace-fail '/bin/echo -e' "$(which echo) -e" \
        --replace-fail '$(UTILS_DEVTOOL_PATH)zip' $(which zip) \
        --replace-fail '$(UTILS_USR_BIN_PATH)unzip' $(which unzip) \
        --replace-fail '$(UTILS_COMMAND_PATH)grep' $(which grep) \
        --replace-fail '$(UTILS_COMMAND_PATH)egrep' $(which egrep) \
        --replace-fail '$(UTILS_COMMAND_PATH)sed' $(which sed) \
        --replace-fail '$(USRBIN_PATH)gawk' $(which gawk) \
        --replace-fail '$(UTILS_USR_BIN_PATH)nm' $(which nm) \
        --replace-fail '$(UTILS_USR_BIN_PATH)find' $(which find) \
        --replace-fail '$(UTILS_USR_BIN_PATH)ar' $(which ar) \
        --replace-fail '$(UTILS_COMMAND_PATH)sh' $(which bash) \
        --replace-fail '$(UTILS_COMMAND_PATH)cpio' $(which cpio) \
        --replace-fail '$(UTILS_USR_BIN_PATH)cpio' $(which cpio) \
        --replace-fail '$(UTILS_COMMAND_PATH)tar' $(which tar) \
        --replace-fail '$(UTILS_USR_BIN_PATH)tar' $(which tar) \
        --replace-warn '$(COMPILER_PATH)nm' $(which nm) \
        --replace-warn '$(COMPILER_PATH)ar' $(which ar) \
        --replace-warn '$(UTILS_USR_BIN_PATH)ldd' $(which ldd) \
        --replace-warn '$(UTILS_USR_BIN_PATH)readelf' $(which readelf) \

      # Exit openjdk source
      popd

      # Add this since we can't set it in `configureFlags` below
      configureFlagsArray+=("--with-parallel-jobs=$NIX_BUILD_CORES")

      # Exit source to prepare for build
      popd
    '';

  env = {
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    NIX_CFLAGS_COMPILE = "-std=gnu17 -Wno-error=format-security -Wno-error=implicit-int -Wno-error=return-mismatch -Wno-error=implicit-function-declaration";
    CLASSPATH = "${classpathTools}:${rtJar}";
    JAVACFLAGS = "-cp ${classpathTools}:${rtJar} -encoding utf-8";
    UTILS_COMMAND_PATH = "${coreutils}/bin/";
    UTILS_USR_BIN_PATH = "${coreutils}/bin/";
    UTILS_CCS_BIN_PATH = "${stdenv.cc}/bin/";
    ALT_CUPS_HEADERS_PATH = "${cups.dev}/include";
    ALT_FREETYPE_HEADERS_PATH = "${freetype}/include";
    ALT_FREETYPE_LIB_PATH = "${freetype}/lib";
    ALT_OBJCOPY = lib.getExe' stdenv.cc "objcopy";
    DISABLE_HOTSPOT_OS_VERSION_CHECK = "ok";
    CPATH =
      let
        xExtPath = pack: "${pack}/include/x11/extensions";
      in
      "${xExtPath libxcomposite}:${xExtPath libxrender}:${xExtPath libxtst}:${xExtPath libxinerama}";
    # This is a dirty hack to fix a `configure` issue. This gates a patch that we need to enable,
    # So we force it to be "yes" even though by default it is set to "no"
    it_cv_diamond = "yes";
  };

  configureFlags = [
    "--enable-system-lcms"
    "--disable-system-sctp"
    "--disable-system-gtk"
    "--disable-system-gio"
    "--disable-system-gconf"
    "--enable-bootstrap"
    "--without-rhino"
    "--with-openjdk-src-dir=./openjdk-src"
    "--with-ecj=${ecj_4}/bin/javac"
    "--with-jdk-home=${classpath_latest}"
    "--with-java=${jamvm_2}/bin/jamvm"
    "--with-jar=${lib.getExe fastjar}"
    "--with-jamvm-src-zip=${jamvm_src}"
    "--enable-jamvm"
    "--without-jamvm-checksum"
    "--disable-downloading"
    "--disable-tests"
    "--disable-docs"
    "--disable-nss"
  ];

  nativeBuildInputs = [
    # bootstrap dependencies
    ecj_4
    classpath_latest
    jamvm_2
    ant_1_8
    # system dependencies
    attr
    autoconf
    automake
    coreutils
    cpio
    fastjar
    gawk
    gnugrep
    gnused
    hostname
    libtool
    libxslt
    perl
    pkg-config
    procps
    unzip
    wget
    which
    zip
  ];

  buildInputs = [
    alsa-lib
    cups
    freetype
    fontconfig
    giflib
    krb5
    lcms2
    libjpeg_turbo
    libpng
    libx11
    libxcomposite
    libxi
    libxinerama
    libxrender
    libxt
    libxtst
    pcsclite
    zlib
  ];

  # This saves time, and the real test we do is compiling further JDKs, so this is fine to disable.
  doCheck = false;

  meta = {
    description = "Java development kit";
    homepage = "https://icedtea.classpath.org";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
