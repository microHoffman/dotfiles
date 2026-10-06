#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

# Skills only: do not run upstream `githits init`, which changes MCP transport.
install_global_skills https://github.com/githits-com/githits-cli \
  githits-mcp githits-code githits-package githits-onboarding
