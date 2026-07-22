#!/usr/bin/env bash
set -euo pipefail

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'install-codex-seo: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd curl
seo_ref="${CODEX_SEO_REF:-v1.9.6-codex.5}"
installer_url="https://raw.githubusercontent.com/AgriciDaniel/codex-seo/${seo_ref}/install.sh"
temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT
installer_path="${temporary_dir}/install.sh"

curl -fsSL "$installer_url" -o "$installer_path"
chmod 700 "$installer_path"
nix_ld_library_path="/run/current-system/sw/share/nix-ld/lib"
if [ -d "$nix_ld_library_path" ]; then
  if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    nix_ld_library_path="${nix_ld_library_path}:${LD_LIBRARY_PATH}"
  fi
  CODEX_SEO_REF="$seo_ref" LD_LIBRARY_PATH="$nix_ld_library_path" \
    bash "$installer_path"
else
  CODEX_SEO_REF="$seo_ref" bash "$installer_path"
fi
