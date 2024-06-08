# This list is based upon:
# https://github.com/TUM-DSE/doctor-cluster-config/blob/master/pkgs/xilinx/fhs-env.nix
pkgs:

(with pkgs; [
  bash
  coreutils
  # fool buildFHSEnvChroot to think we are not on an FHS environment. See also:
  # https://unix.stackexchange.com/a/527763/135796
  (writeTextFile {
    name = "xilinx-fhs-etc_issue";
    # Upstream doesn't officially support NixOS (unfortunately), so it
    # doesn't matter really what we write here
    text = ''
      Welcome to NixOS (FHS environment for nix-xilinx)
    '';
    destination = "/etc/issue";
  })
  zlib
  lsb-release
  stdenv.cc.cc
  ncurses5
  xorg.libXext
  xorg.libX11
  xorg.libXrender
  xorg.libXtst
  xorg.libXi
  xorg.libXft
  xorg.libxcb
  xorg.libxcb
  # common requirements
  freetype
  fontconfig
  glib
  # For string.h, see https://gitlab.com/doronbehar/nix-xilinx/-/issues/4
  glibc.dev
  gtk2
  gtk3
  libxcrypt-legacy
  # For fetching project templates when creating projects
  gitMinimal
  # For the `arch` command
  toybox

  # to compile some xilinx examples
  opencl-clhpp
  ocl-icd
  opencl-headers

  # from installLibs.sh
  graphviz
  gcc
  unzip
  nettools
])
