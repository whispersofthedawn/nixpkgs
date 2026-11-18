{
  lib,
  runCommand,
  makeWrapper,
  clippy-unwrapped,
  sysroot,
}:

runCommand "${clippy-unwrapped.pname}-wrapper-${clippy-unwrapped.version}"
  {
    preferLocalBuild = true;
    strictDeps = true;
    inherit (clippy-unwrapped) outputs;

    nativeBuildInputs = [ makeWrapper ];

    meta = clippy-unwrapped.meta // {
      description = "${clippy-unwrapped.meta.description} (wrapper script)";
      priority = 10;
    };
  }

  ''
    mkdir -p $out/bin
    makeWrapper ${clippy-unwrapped}/bin/cargo-clippy $out/bin/cargo-clippy \
      --set-default SYSROOT ${sysroot}

    makeWrapper ${clippy-unwrapped}/bin/clippy-driver $out/bin/clippy-driver \
      --set-default SYSROOT ${sysroot}

    ${lib.concatMapStrings (output: "ln -s ${clippy-unwrapped.${output}} \$${output}\n") (
      lib.remove "out" clippy-unwrapped.outputs
    )}
  ''
