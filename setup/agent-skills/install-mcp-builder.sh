#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

repository_path="${1:-}"
if [ -z "$repository_path" ]; then
  printf 'Usage: %s /path/to/own_mcp\n' "$0" >&2
  exit 2
fi
repository_path="$(cd -- "$repository_path" && pwd)"
require_repository "$repository_path" "OWN MCP repository"
if [ ! -f "$repository_path/package.json" ] ||
  ! grep -q '"name"[[:space:]]*:[[:space:]]*"own-context-mcp"' "$repository_path/package.json"; then
  printf 'install-mcp-builder: expected the own-context-mcp package: %s\n' \
    "$repository_path" >&2
  exit 1
fi

install_repository_skill \
  "$repository_path" \
  https://github.com/anthropics/skills \
  mcp-builder
