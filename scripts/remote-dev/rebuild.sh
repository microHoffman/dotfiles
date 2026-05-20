#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-${HOME}/dotfiles}"

cd "${repo_root}"
exec sudo nixos-rebuild switch --flake ./nix#remote-dev
