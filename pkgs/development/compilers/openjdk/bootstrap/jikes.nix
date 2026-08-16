{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jikes";
  version = "1.22";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "mirror://sourceforge/jikes/Jikes/${finalAttrs.version}/jikes-${finalAttrs.version}.tar.bz2";
    hash = "sha256-DLAsdjvEQTSfbTjKzVKt92IwLM46COJp8fdfcm5uFOM=";
  };

  meta = {
    description = "Java source code to bytecode compiler";
    license = lib.licenses.ibmpl10;
    platforms = lib.platforms.unix;
  };
})
