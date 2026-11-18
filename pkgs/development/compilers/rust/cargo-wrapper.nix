{
  runCommand,
  makeWrapper,
  cargo-unwrapped,
  rustc,
  ...
}:
runCommand "${cargo-unwrapped.pname}-wrapper-${cargo-unwrapped.version}"
  {
    nativeBuildInputs = [ makeWrapper ];

    inherit (cargo-unwrapped) meta;
  }
  ''
    mkdir -p $out/bin
    ln -s ${cargo-unwrapped}/share $out/share

    makeWrapper "${cargo-unwrapped}/bin/cargo" "$out/bin/cargo" \
      --prefix PATH : "${rustc}/bin"
  ''
