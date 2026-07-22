#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_file="${script_dir}/foundry.toml"
foundry_dir="${FOUNDRY_INSTALL_DIR:-${HOME}/.foundry}"
target_file="${foundry_dir}/foundry.toml"

if [[ ! -f "${source_file}" ]]; then
  echo "Foundry config template not found: ${source_file}" >&2
  exit 1
fi

mkdir -p "${foundry_dir}"
install -m 0644 "${source_file}" "${target_file}"

echo "Foundry config installed at ${target_file}."
