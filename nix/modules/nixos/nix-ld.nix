{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      bzip2
      curl
      dbus
      fontconfig
      freetype
      glib
      gtk3
      libGL
      libffi
      libxcrypt
      libxml2
      ncurses
      nspr
      nss
      openssl
      readline
      sqlite
      stdenv.cc.cc
      systemd
      util-linux
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxkbfile
      xz
      zlib
      zstd
    ];
  };
}
