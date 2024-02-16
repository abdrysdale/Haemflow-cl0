{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  NIX_SHELL_PRESERVE_PROMPT=1;
  buildInputs = [
    pkgs.python312Packages.numpy
    pkgs.python312Packages.matplotlib
    pkgs.python312Packages.h5py
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];
  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      pkgs.stdenv.cc.cc
      pkgs.zlib
    ]}
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib/gcc/x86_64-pc-linux-gnu/13/"
  '';
}
