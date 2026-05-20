#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-${HOME}/dotfiles}"

cd "${repo_root}"
nix flake update --flake "path:${repo_root}/nix"
git status --short

cat <<'EOF'

Review the lockfile diff, then rebuild:
  scripts/remote-dev/rebuild.sh

Commit nix/flake.lock after the rebuild is verified.
EOF
