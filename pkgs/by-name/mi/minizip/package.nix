{
  lib,
  stdenv,
  cmake,
  zlib,
  testers,
  enableStatic ? stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "minizip";
  inherit (zlib) src version;

  sourceRoot = "${finalAttrs.src.name}/contrib/minizip";

  strictDeps = true;

  nativeBuildInputs = [ cmake ];

  buildInputs = [ zlib ];

  cmakeFlags = [
    (lib.cmakeBool "MINIZIP_BUILD_SHARED" (!enableStatic))
    (lib.cmakeBool "MINIZIP_BUILD_STATIC" enableStatic)
    # TODO: test if this is useful / builds less
    # (lib.cmakeBool "MINIZIP_BUILD_TESTING" finalAttrs.finalPackage.doCheck)
  ];

  # TODO: check if this is doing anything?
  doCheck = true;

  passthru.tests.pkg-config = testers.hasPkgConfigModules {
    package = finalAttrs.finalPackage;
    versionCheck = true;
  };

  __structuredAttrs = true;

  meta = {
    description = "Compression library implementing the deflate compression method found in gzip and PKZIP";
    inherit (zlib.meta) license homepage;
    pkgConfigModules = [ "minizip" ];
    platforms = lib.platforms.unix;
  };
})
