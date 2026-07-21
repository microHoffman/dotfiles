#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"${script_dir}/_install-pwn-skill.sh" "${1:-}" secure-workflow-guide
