{
  lib,
  callPackage,
  newScope,
  ...
}:
let
  packages = lib.packagesFromDirectoryRecursive {
    inherit callPackage newScope;
    directory = ./bootstrap;
  };
in
packages
