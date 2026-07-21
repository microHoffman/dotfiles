#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

install_global_skill https://github.com/getsentry/sentry-agent-skills sentry-fix-issues

metadata_file="${HOME}/.agents/skills/sentry-fix-issues/agents/openai.yaml"
if [ -e "$metadata_file" ]; then
  if ! grep -Eq '^  allow_implicit_invocation: false$' "$metadata_file"; then
    printf 'install-sentry-fix-issues: upstream metadata exists without the required explicit-only policy: %s\n' \
      "$metadata_file" >&2
    exit 1
  fi
else
  install -d -m 755 -- "$(dirname -- "$metadata_file")"
  # The dollar-prefixed skill name is intentionally literal in the YAML.
  # shellcheck disable=SC2016
  printf '%s\n' \
    'interface:' \
    '  display_name: "Sentry: Fix Issues"' \
    '  short_description: "Explicit workflow for fixing Sentry issues"' \
    '  default_prompt: "Use $sentry-fix-issues to investigate and fix the requested Sentry issue."' \
    'policy:' \
    '  allow_implicit_invocation: false' >"$metadata_file"
fi
