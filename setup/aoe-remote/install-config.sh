#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
codex_config="${CODEX_CONFIG_FILE:-${HOME}/.codex/config.toml}"
aoe_config="${AOE_CONFIG_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/agent-of-empires/config.toml}"

install_if_missing() {
  source_file="$1"
  target_file="$2"
  label="$3"

  install -d -m 700 -- "$(dirname -- "$target_file")"
  if [ -e "$target_file" ]; then
    printf 'Preserving existing %s config: %s\n' "$label" "$target_file"
    printf 'Compare it manually with: %s\n' "$source_file"
    return
  fi

  install -m 600 -- "$source_file" "$target_file"
  printf 'Installed %s baseline: %s\n' "$label" "$target_file"
}

install_if_missing "${script_dir}/codex-config.toml" "$codex_config" "Codex"
install_if_missing "${script_dir}/aoe-config.toml" "$aoe_config" "AoE"
