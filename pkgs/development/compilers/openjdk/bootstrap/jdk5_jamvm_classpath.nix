{
  runCommand,
  writeShellScript,
  jamvm_1,
  classpath_0_99,
}:
let
  mkClasspathTool =
    name: class:
    let
      script = writeShellScript name ''
        set -eu
        exec ${jamvm_1}/bin/jamvm -Xnocompact -Xnoinlining \
          -classpath ${classpath_0_99}/share/classpath/tools.zip \
          gnu.classpath.tools.${name}.${class} "$@"
      '';
    in
    ''
      ln -s ${script} $out/bin/${name}
    '';
in
runCommand "jdk5-jamvm-classpath" { } ''
  mkdir -p $out/bin
  ${mkClasspathTool "javah" "Main"}
  ${mkClasspathTool "rmic" "Main"}
  ${mkClasspathTool "rmid" "Main"}
  ${mkClasspathTool "orbd" "Main"}
  ${mkClasspathTool "rmiregistry" "Main"}
  ${mkClasspathTool "native2ascii" "Native2ASCII"}
''
