#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  REMOTE_DEV_CONFIRM_DESTROY=yes scripts/remote-dev/install-destroy-with-nixos-anywhere.sh root@<public-ip>

This is for initial install or reinstall only. It runs nixos-anywhere with disko,
which can repartition and format the target disk configured in nix/shared/vars.nix.

Set REMOTE_DEV_NIX_STORE=/tmp/dotfiles-nix-store to make both preflight checks
and nixos-anywhere use that alternate Nix store.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

if [ "${REMOTE_DEV_CONFIRM_DESTROY:-}" != "yes" ]; then
  usage
  printf '\nRefusing to continue without REMOTE_DEV_CONFIRM_DESTROY=yes.\n' >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
vars_file="${repo_root}/nix/shared/vars.nix"
target_host="$1"

"${repo_root}/scripts/remote-dev/check-config.sh"

nix_cmd=(nix)
if [ -n "${REMOTE_DEV_NIX_STORE:-}" ]; then
  nix_cmd+=(--store "${REMOTE_DEV_NIX_STORE}")
  export NIX_REMOTE="${REMOTE_DEV_NIX_STORE}"
fi

allow_public_ssh="$(
  "${nix_cmd[@]}" eval --impure --raw --expr "let vars = import ${vars_file}; in if vars.allowPublicSsh then \"true\" else \"false\""
)"

if [ "${allow_public_ssh}" != "true" ] && [ "${REMOTE_DEV_ALLOW_NO_PUBLIC_SSH:-}" != "yes" ]; then
  cat >&2 <<'EOF'
install-destroy-with-nixos-anywhere: refusing to install with allowPublicSsh = false.

This install path creates a fresh host that has not joined Tailscale yet, so the
first login normally needs public SSH enabled for bootstrap. Set
allowPublicSsh = true in nix/shared/vars.nix before initial install/reinstall.

Override with REMOTE_DEV_ALLOW_NO_PUBLIC_SSH=yes only if you have another
confirmed first-login path to the freshly installed system.
EOF
  exit 1
fi

flake_ref="path:${repo_root}/nix#remote-dev"

printf 'About to run destructive install against %s using %s\n' "${target_host}" "${flake_ref}" >&2
sleep 5

exec "${nix_cmd[@]}" run github:nix-community/nixos-anywhere -- \
  --flake "${flake_ref}" \
  --target-host "${target_host}"
