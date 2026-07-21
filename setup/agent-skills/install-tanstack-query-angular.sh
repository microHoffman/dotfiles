#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

repository_path="${1:-}"
if [ -z "$repository_path" ]; then
  printf 'Usage: %s /path/to/depoto-client\n' "$0" >&2
  exit 2
fi
repository_path="$(cd -- "$repository_path" && pwd)"
require_repository "$repository_path" "Depoto Client repository"
if [ ! -f "$repository_path/package.json" ] ||
  ! grep -q '"@tanstack/angular-query-experimental"' "$repository_path/package.json"; then
  printf 'install-tanstack-query-angular: target does not use Angular Query: %s\n' \
    "$repository_path" >&2
  exit 1
fi

install_repository_skill \
  "$repository_path" \
  https://github.com/microHoffman/agent-skills \
  tanstack-query-angular
