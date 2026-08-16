{
  classpath,
  jamvm,
  writeShellScript,
}:
let
  classpathShare = "${classpath}/share/classpath";
  wrapperScript = writeShellScript "ecj-javac.sh" ''
    set -eu

    declare -a vmArgs ecjArgs
    declare -A defaultArgs
    bootClasspath=${classpathShare}/glibj.zip:${classpathShare}/tools.zip
    vmArgs=()
    ecjArgs=()
    defaultArgs=(
        -bootclasspath ''${bootClasspath}
        -source 1.5
        -target 1.5
        -cp .
    )

    ## split into args for (jam)vm and ecj:
    ## vm args are stripped of -J
    ## ecj args are deleted from defaultArgs
    for flag in "$@"
    do if [[ $flag =~ ^-J ]]
       then vmArgs+=( "''${flag:2}" )
       else unset defaultArgs[$flag]
            ecjArgs+=( "''${flag}" )
       fi
    done

    ## apply (left over) default args
    for defFlag in "''${!defaultArgs[@]}"
    do ecjArgs+=( "$defFlag" "''${defaultArgs[$defFlag]}" )
    done

    CLASSPATH=@ecjPath@/share/java/ecj-bootstrap.jar:''${CLASSPATH:-} exec ${jamvm}/bin/jamvm "''${vmArgs[@]}" org.eclipse.jdt.internal.compiler.batch.Main -nowarn "''${ecjArgs[@]}"
  '';

in
wrapperScript
