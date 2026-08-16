# OpenJDK Libre Bootstrap

This is the full bootstrap chain to build OpenJDK from source. Previously, we downloaded a pre-built JDK distribution from
Adoptium to build nixpkgs' JDK distributions. Now, instead what we do is build this bootstrap chain, which removes any binaries
from the critical bootstrap path.
