{
  lib,
  stdenv,
  removeReferencesTo,
  pkgsBuildBuild,
  pkgsBuildHost,
  pkgsBuildTarget,
  targetPackages,
  llvmShared,
  llvmSharedForBuild,
  llvmSharedForHost,
  llvmSharedForTarget,
  llvmPackages,
  runCommandLocal,
  fetchurl,
  file,
  python3,
  cargo,
  cmake,
  rustc,
  rustfmt,
  pkg-config,
  bashNonInteractive,
  openssl,
  xz,
  zlib,
  rust-jemalloc-sys,
  bintools,
  which,
  libffi,
  withBundledLLVM ? false,
  enableRustcDev ? true,
  version,
  sha256,
  patches ? [ ],
  fd,
  ripgrep,
  wezterm,
  firefox,
  thunderbird,
}:

let
  inherit (lib)
    optionals
    optional
    optionalString
    ;
  useLLVM = stdenv.hostPlatform.useLLVM or false;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rustc";
  inherit version;

  src = fetchurl {
    url = "https://static.rust-lang.org/dist/rustc-${version}-src.tar.gz";
    inherit sha256;
    # See https://nixos.org/manual/nixpkgs/stable/#using-git-bisect-on-the-rust-compiler
    passthru.isReleaseTarball = true;
  };

  __darwinAllowLocalNetworking = true;

  # rustc complains about modified source files otherwise
  dontUpdateAutotoolsGnuConfigScripts = true;

  # Running the default `strip -S` command on Darwin corrupts the
  # .rlib files in "lib/".
  #
  # See https://github.com/NixOS/nixpkgs/pull/34227
  #
  # Running `strip -S` when cross compiling can harm the cross rlibs.
  # See: https://github.com/NixOS/nixpkgs/pull/56540#issuecomment-471624656
  stripDebugList = [ "bin" ];

  env = {
    # TODO: what the fuck are all these freebsd-specific conditionals in this
    # file? there's some we deleted already, too. surely, *surely*, there's
    # some more generic property these are getting at than literally "is
    # freebsd"? maybe "target platform uses libc++ stdenv"? go investigate
    # this, figure out that property, and then quash whatever nonsense. either
    # some of these should be host platform-dependent, or they shouldn't exist
    # at all.
    NIX_LDFLAGS = toString (
      # when linking stage1 libstd: cc: undefined reference to `__cxa_begin_catch'
      # This doesn't apply to cross-building for FreeBSD because the host
      # uses libstdc++, but the target (used for building std) uses libc++
      optional (
        stdenv.hostPlatform.isLinux && !withBundledLLVM && !stdenv.targetPlatform.isFreeBSD && !useLLVM
      ) "--push-state --as-needed -lstdc++ --pop-state"
      ++
        optional
          (stdenv.hostPlatform.isLinux && !withBundledLLVM && !stdenv.targetPlatform.isFreeBSD && useLLVM)
          "--push-state --as-needed -L${llvmPackages.libcxx}/lib -lc++ -lc++abi -lLLVM-${lib.versions.major llvmPackages.llvm.version} --pop-state"
      ++ optional (stdenv.hostPlatform.isDarwin && !withBundledLLVM) "-lc++ -lc++abi"
      ++ optional stdenv.hostPlatform.isDarwin "-rpath ${llvmSharedForHost.lib}/lib"
    );

    RUSTFLAGS = lib.concatStringsSep " " (
      [
        # Increase codegen units to introduce parallelism within the compiler.
        "-Ccodegen-units=10"
      ]
      ++ lib.optionals (stdenv.hostPlatform.rust.rustcTargetSpec == "x86_64-unknown-linux-gnu") [
        # Upstream defaults to lld on x86_64-unknown-linux-gnu, we want to use our linker
        "-Clinker-features=-lld"
        "-Clink-self-contained=-linker"
      ]
    );
    RUSTDOCFLAGS = "-A rustdoc::broken-intra-doc-links";
  };

  # We need rust to build rust. If we don't provide it, configure will try to download it.
  # Reference: https://github.com/rust-lang/rust/blob/master/src/bootstrap/configure.py
  configureFlags =
    let
      prefixForStdenv = stdenv: "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}";
      ccPrefixForStdenv =
        stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang" else "cc"}";
      cxxPrefixForStdenv =
        stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang++" else "c++"}";
      setBuild = "--set=target.\"${stdenv.buildPlatform.rust.rustcTargetSpec}\"";
      setHost = "--set=target.\"${stdenv.hostPlatform.rust.rustcTargetSpec}\"";
      ccForBuild = ccPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
      cxxForBuild = cxxPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
      ccForHost = ccPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
      cxxForHost = cxxPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
    in
    [
      "--sysconfdir=${placeholder "out"}/etc"
      "--release-channel=stable"
      "--set=build.rustc=${rustc}/bin/rustc"
      "--set=build.cargo=${cargo}/bin/cargo"
    ]
    ++ lib.optionals (!(finalAttrs.src.passthru.isReleaseTarball or false)) [
      # release tarballs vendor the rustfmt source; when
      # git-bisect'ing from upstream's git repo we must prevent
      # attempts to download the missing source tarball
      "--set=build.rustfmt=${rustfmt}/bin/rustfmt"
    ]
    ++ [
      "--tools=rustc,rustdoc,rust-analyzer-proc-macro-srv"
      "--enable-rpath"
      "--enable-vendor"
      # For Nixpkgs it makes more sense to use stdenv's linker than
      # letting rustc build its own.
      "--disable-lld"
      "--build=${stdenv.buildPlatform.rust.rustcTargetSpec}"
      "--host=${stdenv.hostPlatform.rust.rustcTargetSpec}"

      "${setBuild}.cc=${ccForBuild}"
      "${setHost}.cc=${ccForHost}"

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
      "${setBuild}.linker=${ccForBuild}"
      "${setHost}.linker=${ccForHost}"

      "${setBuild}.cxx=${cxxForBuild}"
      "${setHost}.cxx=${cxxForHost}"

      "${setBuild}.crt-static=${lib.boolToString stdenv.buildPlatform.isStatic}"
      "${setHost}.crt-static=${lib.boolToString stdenv.hostPlatform.isStatic}"
    ]
    ++ optionals (!withBundledLLVM) [
      "--enable-llvm-link-shared"
      "${setBuild}.llvm-config=${llvmSharedForBuild.dev}/bin/llvm-config"
      "${setHost}.llvm-config=${llvmSharedForHost.dev}/bin/llvm-config"
    ]
    ++ optionals (stdenv.hostPlatform.isLinux && !(stdenv.hostPlatform.useLLVM or false)) [
      "--enable-profiler" # build libprofiler_builtins
    ]
    ++ optionals stdenv.hostPlatform.isDarwin [
      # potentially other llvm targets work with the same fix?
      "--enable-profiler" # build libprofiler_builtins
    ]
    ++ optionals stdenv.buildPlatform.isMusl [
      "${setBuild}.musl-root=${pkgsBuildBuild.targetPackages.stdenv.cc.libc}"
    ]
    ++ optionals stdenv.hostPlatform.isMusl [
      "${setHost}.musl-root=${pkgsBuildHost.targetPackages.stdenv.cc.libc}"
    ]
    ++ optionals (useLLVM && !stdenv.hostPlatform.isFreeBSD) [
      # https://github.com/NixOS/nixpkgs/issues/311930
      "--llvm-libunwind=${if withBundledLLVM then "in-tree" else "system"}"
      "--enable-use-libcxx"
    ]
    ++ optionals (!stdenv.hostPlatform.isx86_32) [
      # This enables frame pointers for the compiler itself.
      #
      # Note that when compiling std, frame pointers (or at least non-leaf
      # frame pointers, depending on version) are unconditionally enabled and
      # cannot be overridden, so we do not touch that. (Also note this only
      # applies to functions that can be immediately compiled when building
      # std. Generic functions that do codegen when called in user code obey
      # -Cforce-frame-pointers specified then, if any)
      "--set=rust.frame-pointers"
    ];

  # the rust build system complains that nix alters the checksums
  dontFixLibtool = true;

  inherit patches;

  postPatch = ''
    patchShebangs src/etc

    # rust-lld is the name rustup uses for its bundled lld, so that it
    # doesn't conflict with any system lld.  This is not an
    # appropriate default for Nixpkgs, where there is no rust-lld.
    substituteInPlace compiler/rustc_target/src/spec/*/*.rs \
      --replace-quiet '"rust-lld"' '"lld"'

    ${optionalString (!withBundledLLVM) "rm -rf src/llvm"}

    # Useful debugging parameter
    # export VERBOSE=1
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    # Replace hardcoded path to strip with llvm-strip
    # https://github.com/NixOS/nixpkgs/issues/299606
    substituteInPlace compiler/rustc_codegen_ssa/src/back/link.rs \
      --replace-fail "/usr/bin/strip" "${lib.getExe' llvmShared "llvm-strip"}"
  ''
  + lib.optionalString (!(finalAttrs.src.passthru.isReleaseTarball or false)) ''
    mkdir .cargo
    cat > .cargo/config.toml <<\EOF
    [source.crates-io]
    replace-with = "vendored-sources"
    [source.vendored-sources]
    directory = "vendor"
    EOF
  ''
  + lib.optionalString (stdenv.hostPlatform.isFreeBSD) ''
    # lzma-sys bundles an old version of xz that doesn't build
    # on modern FreeBSD, use the system one instead
    substituteInPlace src/bootstrap/src/core/build_steps/tool.rs \
        --replace 'cargo.env("LZMA_API_STATIC", "1");' ' '
  '';

  # rustc unfortunately needs cmake to compile llvm-rt but doesn't
  # use it for the normal build. This disables cmake in Nix.
  dontUseCmakeConfigure = true;

  depsBuildBuild = [
    pkgsBuildHost.stdenv.cc
    pkg-config
  ];
  depsBuildTarget = lib.optionals stdenv.targetPlatform.isMinGW [ bintools ];

  nativeBuildInputs = [
    file
    python3
    rustc
    cmake
    which
    libffi
    removeReferencesTo
    pkg-config
    xz
  ];

  buildInputs = [
    bashNonInteractive
    openssl
    rust-jemalloc-sys
  ]
  ++ optionals stdenv.hostPlatform.isDarwin [
    zlib
  ]
  ++ optional (!withBundledLLVM) llvmShared.lib
  ++ optional (useLLVM && !withBundledLLVM) llvmPackages.libunwind;

  strictDeps = true;

  outputs = [
    "out"
    "man"
    "doc"
  ];
  setOutputFlags = false;

  postInstall =
    lib.optionalString enableRustcDev ''
      # install rustc-dev components. Necessary to build rls, clippy...
      python x.py dist rustc-dev
      tar xf build/dist/rustc-dev*tar.gz
      cp -r rustc-dev*/rustc-dev*/lib/* $out/lib/
      rm $out/lib/rustlib/install.log
      for m in $out/lib/rustlib/manifest-rust*
      do
        sort --output=$m < $m
      done

    ''
    + ''
      # remove references to llvm-config in lib/rustlib/x86_64-unknown-linux-gnu/codegen-backends/librustc_codegen_llvm-llvm.so
      # and thus a transitive dependency on ncurses
      find $out/lib -name "*.so" -type f -exec remove-references-to -t ${llvmShared} '{}' '+'

      # remove uninstall script that doesn't really make sense for Nix.
      rm $out/lib/rustlib/uninstall.sh
    '';

  configurePlatforms = [ ];

  enableParallelBuilding = true;

  setupHooks = ./setup-hook.sh;

  requiredSystemFeatures = [ "big-parallel" ];

  # Make sure our bootstrap packages don't end up in our runtime closure
  disallowedReferences = [
    cargo
    rustc
  ];

  passthru = {
    llvm = llvmShared;
    inherit llvmPackages;
    inherit (rustc) targetPlatforms targetPlatformsWithHostTools badTargetPlatforms;
    tests = {
      inherit fd ripgrep wezterm;
    }
    // lib.optionalAttrs stdenv.hostPlatform.isLinux { inherit firefox thunderbird; };
  };

  __structuredAttrs = true;

  meta = {
    homepage = "https://www.rust-lang.org/";
    description = "Safe, concurrent, practical language";
    mainProgram = "rustc";
    teams = [ lib.teams.rust ];
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    platforms = rustc.targetPlatformsWithHostTools;
    # If rustc can't target a platform, we also can't build rustc for
    # that platform.
    badPlatforms = rustc.badTargetPlatforms;
  };
})
