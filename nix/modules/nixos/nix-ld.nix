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
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxcb
      libxkbfile
      xz
      zlib
      zstd
    ];
  };
}
