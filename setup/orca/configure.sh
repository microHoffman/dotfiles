#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'Usage: %s\nApplies Codex-first launch defaults and Codex/Claude preset Quick Commands to the local Orca runtime.\n' "${0##*/}" >&2
  exit 2
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install_root="${ORCA_INSTALL_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/orca-install}"
export ORCA_CONFIGURE_APP_DIR="$install_root/current"
ELECTRON_RUN_AS_NODE=1 exec "$ORCA_CONFIGURE_APP_DIR/orca-ide" "$script_dir/configure.cjs"
