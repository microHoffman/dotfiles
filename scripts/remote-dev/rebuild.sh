#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-${HOME}/dotfiles}"

cd "${repo_root}"
nix flake check ./nix --show-trace
nix build ./nix#nixosConfigurations.remote-dev.config.system.build.toplevel --no-link
sudo nixos-rebuild dry-activate --flake ./nix#remote-dev
exec sudo nixos-rebuild switch --flake ./nix#remote-dev
