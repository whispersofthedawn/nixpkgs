{
  stdenv,
  fetchurl,
  fetchpatch,
  lib,
  pkg-config,
  makeWrapper,
  curl,
  openssl,
  tpm2-tss,
  libuuid,
  abrmdSupport ? true,
  tpm2-abrmd ? null,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tpm2-tools";
  version = "5.8";

  src = fetchurl {
    url = "https://github.com/tpm2-software/tpm2-tools/releases/download/${finalAttrs.version}/tpm2-tools-${finalAttrs.version}.tar.gz";
    sha256 = "sha256-HLcxhcroFLThXHwtCyJkLWQPr0h3X0FWof2S7fhL73M=";
  };

  patches = [
    (fetchpatch {
      name = "lib-objecth-include-openssl-errh.patch";
      url = "https://github.com/tpm2-software/tpm2-tools/commit/c2b2c4e5cdc5bbc61779eb4271d5c317efb8c067.patch";
      hash = "sha256-TW6/0avsOGK8aPebm11r3kODgx+NvV8N+IffSeY+/M8=";
    })
  ];

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = [
    curl
    openssl
    tpm2-tss
    libuuid
  ];

  preFixup =
    let
      ldLibraryPath = lib.makeLibraryPath (
        [
          tpm2-tss
        ]
        ++ (lib.optional abrmdSupport tpm2-abrmd)
      );
    in
    ''
      wrapProgram $out/bin/tpm2 --suffix LD_LIBRARY_PATH : "${ldLibraryPath}"
      wrapProgram $out/bin/tss2 --suffix LD_LIBRARY_PATH : "${ldLibraryPath}"
    '';

  # Unit tests disabled, as they rely on a dbus session
  #configureFlags = [ "--enable-unit" ];
  doCheck = false;

  meta = {
    description = "Command line tools that provide access to a TPM 2.0 compatible device";
    homepage = "https://github.com/tpm2-software/tpm2-tools";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ scottstephens ];
  };
})
