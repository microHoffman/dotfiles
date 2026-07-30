#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${DOTFILES_COMMANDS_BIN_DIR:-${HOME}/.local/bin}"
commands=(
  "aoe-old-idle"
)

mkdir -p -- "$target_dir"

for command_name in "${commands[@]}"; do
  source_path="${script_dir}/${command_name}"
  target_path="${target_dir}/${command_name}"

  if [[ ! -x "$source_path" ]]; then
    printf 'Shared command is not executable: %s\n' "$source_path" >&2
    exit 1
  fi

  if [[ -e "$target_path" && ! -L "$target_path" ]]; then
    printf 'Refusing to replace non-symlink command: %s\n' "$target_path" >&2
    exit 1
  fi

  ln -sfn -- "$source_path" "$target_path"
  printf 'Installed %s -> %s\n' "$target_path" "$source_path"
done
