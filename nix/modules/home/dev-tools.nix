{ pkgs, ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    silent = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    bat
    btop
    bun
    cmake
    curl
    dnsutils
    docker
    docker-compose
    eza
    fd
    file
    foundry
    fzf
    gcc
    gh
    glab
    gnumake
    htop
    inetutils
    jq
    lsof
    mariadb.client
    ncdu
    nodejs_24
    openssl
    pkg-config
    postgresql
    python3
    redis
    ripgrep
    rsync
    rustup
    sqlite
    tmux
    tree
    unzip
    uv
    wget
    which
    yq-go
    zip
    zlib
  ];
}
