#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
vars_file="${repo_root}/nix/shared/vars.nix"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'check-config: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd nix

nix_cmd=(nix)
if [ -n "${REMOTE_DEV_NIX_STORE:-}" ]; then
  nix_cmd+=(--store "${REMOTE_DEV_NIX_STORE}")
fi

key_count="$(
  "${nix_cmd[@]}" eval --impure --raw --expr "let vars = import ${vars_file}; in toString (builtins.length vars.authorizedSshKeys)"
)"

if [ "${key_count}" = "0" ]; then
  printf 'check-config: add at least one public SSH key to nix/shared/vars.nix before installing.\n' >&2
  exit 1
fi

if "${nix_cmd[@]}" eval --impure --raw --expr "let vars = import ${vars_file}; in if vars.allowPublicSsh then \"true\" else \"false\"" | grep -qx true; then
  printf 'check-config: allowPublicSsh is true; this is expected only for bootstrap.\n'
fi

"${nix_cmd[@]}" flake check "${repo_root}/nix"
