#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

repository_path="${1:-}"
if [ -z "$repository_path" ]; then
  printf 'Usage: %s /path/to/pwn_protocol\n' "$0" >&2
  exit 2
fi
repository_path="$(cd -- "$repository_path" && pwd)"
require_repository "$repository_path" "PWN Protocol repository"
if [ ! -f "$repository_path/foundry.toml" ]; then
  printf 'install-pwn-protocol-skills: expected the PWN Protocol Foundry repository: %s\n' \
    "$repository_path" >&2
  exit 1
fi

install_repository_skills \
  "$repository_path" \
  https://github.com/trailofbits/skills \
  secure-workflow-guide \
  entry-point-analyzer \
  property-based-testing \
  differential-review \
  fp-check \
  spec-to-code-compliance
