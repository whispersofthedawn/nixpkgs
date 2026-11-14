{
  lib,
  fetchurl,
  net-tools,
  openssl,
  readline,
  stdenv,
  which,
  buildPackages,
}:

stdenv.mkDerivation rec {
  pname = "socat";
  version = "1.8.1.3";

  src = fetchurl {
    url = "http://www.dest-unreach.org/socat/download/socat-${version}.tar.bz2";
    hash = "sha256-JbxkdikrLmFCIJicd7C2/Kh7slJdl0ezGmY5sftgJBg=";
  };

  patches = [
    (fetchurl {
      name = "openssl4-compat.patch";
      url = "https://src.fedoraproject.org/rpms/socat/raw/7f8555fcc934f2ed25b05ed40a5d41c8857ab193/f/socat-1.8.1.0-openssl4.patch";
      hash = "sha256-ZiWPsbH2UjatjajL+2iUhTVkI+fygNyOUk3AEsEaVoc=";
    })
  ];

  postPatch = ''
    patchShebangs test.sh
    substituteInPlace test.sh \
      --replace /bin/rm rm \
      --replace /sbin/ifconfig ifconfig
  '';

  configureFlags =
    lib.optionals (!stdenv.hostPlatform.isLinux) [
      "--disable-posixmq"
    ]
    ++ lib.optionals stdenv.hostPlatform.isFreeBSD [
      "--disable-dccp"
    ];

  buildInputs = [
    openssl
    readline
  ];

  enableParallelBuilding = true;

  nativeCheckInputs = [
    which
    net-tools
  ];
  doCheck = false; # fails a bunch, hangs

  passthru.tests = lib.optionalAttrs stdenv.buildPlatform.isLinux {
    musl = buildPackages.pkgsMusl.socat;
  };

  meta = {
    description = "Utility for bidirectional data transfer between two independent data channels";
    homepage = "http://www.dest-unreach.org/socat/";
    platforms = lib.platforms.unix;
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ryan4yin ];
    mainProgram = "socat";
  };
}
