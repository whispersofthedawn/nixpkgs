{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  autoreconfHook,
  pkg-config,
  libtasn1,
  openssl,
  fuse3,
  glib,
  libseccomp,
  json-glib,
  libtpms,
  unixtools,
  expect,
  socat,
  gmp,
  gnutls,
  perl,
  makeWrapper,

  # Tests
  python3,
  which,
  nixosTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "swtpm";
  version = "0.10.2-unstable-2026-11-02"; # fuse3 support, switch to openssl

  src = fetchFromGitHub {
    owner = "stefanberger";
    repo = "swtpm";
    rev = "04a65fe53ed9c543caef948da6075b3fe595153d";
    hash = "sha256-YkDUSr0LFK3e4kRZYcdA2m1gZTFDp7kkrL43QJR5uTM=";
  };

  nativeBuildInputs = [
    pkg-config
    unixtools.netstat
    expect
    socat
    perl # for pod2man
    python3
    autoreconfHook
    makeWrapper
    # configure.ac does AC_CHECK_PROG([OPENSSL_CLITOOL], [openssl], ...) and
    # errors out when the tool is not on PATH. openssl is in buildInputs for
    # the library, which puts its bin dir on PATH only when build == host, so
    # the check fails when cross-compiling.
    openssl
  ];

  nativeCheckInputs = [
    which
  ];

  buildInputs = [
    libtpms
    openssl
    libtasn1
    glib
    json-glib
    gmp
    gnutls
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    fuse3
    libseccomp
  ];

  configureFlags = [
    "--localstatedir=/var"
    "--with-gnutls"
    # TODO: upstream a patch to fix usage of ASN1_STRING_length properly
    "CFLAGS=-Wno-error=deprecated-declarations"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    "--with-cuse"
  ];

  postPatch = ''
    patchShebangs tests/*

    # Needed for cross-compilation
    substituteInPlace configure.ac --replace-fail 'pkg-config' '${stdenv.cc.targetPrefix}pkg-config'

    # Makefile tries to create the directory /var/lib/swtpm-localca, which fails
    substituteInPlace samples/Makefile.am \
        --replace-fail 'install-data-local:' 'do-not-execute:'

    # Use the correct path to the openssl binary
    # instead of relying on it being in the environment
    substituteInPlace src/swtpm_localca/swtpm_localca.c \
      --replace-fail \
        '#define OPENSSL_TOOL  "openssl"' \
        '#define OPENSSL_TOOL  "${lib.getExe openssl}"'
  '';

  # Workaround for https://github.com/stefanberger/swtpm/issues/795
  postFixup = ''
    wrapProgram "$out/bin/swtpm_localca" --suffix PATH : "$out/bin"
    wrapProgram "$out/bin/swtpm_setup" --suffix PATH : "$out/bin"
  '';

  doCheck = false; # tests which assert on on openssl output need updating, will fix later
  __darwinAllowLocalNetworking = true; # tests do socket things, requires local networking to pass
  enableParallelBuilding = true;

  outputs = [
    "out"
    "man"
  ];

  passthru.tests = { inherit (nixosTests) systemd-cryptenroll; };

  meta = {
    description = "Libtpms-based TPM emulator";
    homepage = "https://github.com/stefanberger/swtpm";
    license = lib.licenses.bsd3;
    maintainers = [ lib.maintainers.baloo ];
    mainProgram = "swtpm";
    platforms = lib.platforms.all;
  };
})
