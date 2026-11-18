{
  lib,
  stdenv,

  pkgsBuildBuild,
  pkgsBuildHost,
  pkgsBuildTarget,
  llvmSharedForBuild,
  llvmSharedForHost,
  llvmSharedForTarget,

  python3,

  cargo-unwrapped,
  rustc-unwrapped,

  targets ? [
    # we require two sets of standard libraries for building a typical rust
    # package: the one used to build build scripts and proc macros, and the one
    # linked into the final artifacts. in a typical buildRustPackage-like
    # environment, these are the build and host platforms. however, we build
    # the sysroot out of the same package set as the compiler, i.e.
    # `nativeBuildInputs` of a rust package. relative to other dependencies, of
    # the kind that would be included in `buildInputs`, this artificially
    # phase-shifts the sysroot earlier such that we instead need to build
    # standard libraries for the host and target platforms instead.
    stdenv.hostPlatform.rust.rustcTargetSpec
    stdenv.targetPlatform.rust.rustcTargetSpec

    # other targets that don't need any extra dependencies to build.
    "wasm32-unknown-unknown"
    "wasm32v1-none"
    "bpfel-unknown-none"
    "bpfeb-unknown-none"
  ],
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "rust-sysroot";
  inherit (rustc-unwrapped) version src;

  nativeBuildInputs = [ python3 ];

  configureFlags =

    let
      prefixForStdenv = stdenv: "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}";
      ccPrefixForStdenv =
        stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang" else "cc"}";
      cxxPrefixForStdenv =
        stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang++" else "c++"}";
      setBuild = "--set=target.\"${stdenv.buildPlatform.rust.rustcTargetSpec}\"";
      setHost = "--set=target.\"${stdenv.hostPlatform.rust.rustcTargetSpec}\"";
      setTarget = "--set=target.\"${stdenv.targetPlatform.rust.rustcTargetSpec}\"";
      ccForBuild = ccPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
      cxxForBuild = cxxPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
      ccForHost = ccPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
      cxxForHost = cxxPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
      ccForTarget = ccPrefixForStdenv pkgsBuildTarget.targetPackages.stdenv;
      cxxForTarget = cxxPrefixForStdenv pkgsBuildTarget.targetPackages.stdenv;
    in
    [
      "--release-channel=stable"
      "--set=change-id=ignore"

      "--set=build.rustc=${rustc-unwrapped}/bin/rustc"
      "--set=build.cargo=${cargo-unwrapped}/bin/cargo"

      "--build=${stdenv.buildPlatform.rust.rustcTargetSpec}"
      "--host=${stdenv.hostPlatform.rust.rustcTargetSpec}"
      "--target=${lib.concatStringsSep "," targets}"
      "--enable-local-rebuild"

      "${setBuild}.cc=${ccForBuild}"
      "${setHost}.cc=${ccForHost}"
      "${setTarget}.cc=${ccForTarget}"

      # The Rust compiler build identifies platforms by Rust target
      # name, and later arguments override previous arguments. This
      # means that when platforms differ in configuration but overlap
      # in Rust target name (for instance, `pkgsStatic`), only one
      # setting will be applied for any given option.
      #
      # This is usually mostly harmless, especially as `fastCross`
      # means that we usually only compile `std` in such cases.
      # However, the build does still need to link helper tools for the
      # build platform in that case. This was breaking the Darwin
      # `pkgsStatic` build, as it was attempting to link build tools
      # with the target platform’s static linker, and failing to locate
      # an appropriate static library for `-liconv`.
      #
      # Since the static build does not link anything for the target
      # platform anyway, we put the target linker first so that the
      # build platform linker overrides it when the Rust target names
      # overlap, allowing the helper tools to build successfully.
      #
      # Note that Rust does not remember these settings in the built
      # compiler, so this does not compromise any functionality of the
      # resulting compiler.
      #
      # The longer‐term fix would be to get Rust to use a more nuanced
      # understanding of platforms, such as by explicitly constructing
      # and passing Rust JSON target definitions that let us
      # distinguish the platforms in cases like these. That would also
      # let us supplant various hacks around the wrappers and hooks
      # that we currently need.
      "${setTarget}.linker=${ccForTarget}"
      "${setBuild}.linker=${ccForBuild}"
      "${setHost}.linker=${ccForHost}"

      "${setBuild}.cxx=${cxxForBuild}"
      "${setHost}.cxx=${cxxForHost}"
      "${setTarget}.cxx=${cxxForTarget}"

      "${setBuild}.crt-static=${lib.boolToString stdenv.buildPlatform.isStatic}"
      "${setHost}.crt-static=${lib.boolToString stdenv.hostPlatform.isStatic}"
      "${setTarget}.crt-static=${lib.boolToString stdenv.targetPlatform.isStatic}"

      "--enable-llvm-link-shared"
      "${setBuild}.llvm-config=${llvmSharedForBuild.dev}/bin/llvm-config"
      "${setHost}.llvm-config=${llvmSharedForHost.dev}/bin/llvm-config"
      "${setTarget}.llvm-config=${llvmSharedForTarget.dev}/bin/llvm-config"

      "--set=target.wasm32-unknown-unknown.optimized-compiler-builtins=false"
      "--set=target.wasm32v1-none.optimized-compiler-builtins=false"

      # TODO: build docs?
    ];

  buildPhase = ''
    runHook preBuild

    python x.py build --jobs "$NIX_BUILD_CORES" --stage 0 sysroot

    runHook postBuild
  '';

  # TODO: there has *got* to be a better way to do this install. like, surely
  # bootstrap has some machinery for this? figure it out.
  installPhase = ''
    runHook preInstall

    cp -r build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-sysroot $out

    rm -f $out/lib/rustlib/rustc-src/rust
    ln -s "${rustc-unwrapped}/lib/rustlib/rustc-src/rust" "$out/lib/rustlib/rustc-src/rust"

    runHook postInstall
  '';

  meta = {
    homepage = "https://www.rust-lang.org/";
    description = "Precompiled Rust standard libraries and target runtime artifacts";
    teams = [ lib.teams.rust ];
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    platforms = rustc-unwrapped.targetPlatforms;
  };
})
