#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

failures=()

run_step() {
  local label="$1"
  local status
  shift

  printf '\n==> %s\n' "$label"
  if "$@"; then
    printf 'ok   %s\n' "$label"
  else
    status=$?
    failures+=("${label} (exit ${status})")
    printf 'fail %s (exit %s); continuing with independent installers\n' \
      "$label" "$status" >&2
  fi
}

run_step "ActiveCollab CLI and skill" \
  "${script_dir}/install-activecollab.sh"

run_step "agent-browser CLI, browser, and skill" \
  "${script_dir}/install-agent-browser.sh"

run_step "microHoffman agent skills" install_global_skills \
  https://github.com/microHoffman/agent-skills \
  create-pull-request \
  github-issues \
  gitlab-create-mr

run_step "OpenZeppelin smart-contract skills" install_global_skills \
  https://github.com/OpenZeppelin/openzeppelin-skills \
  develop-secure-contracts \
  upgrade-solidity-contracts

run_step "Matt Pocock engineering and productivity skills" install_global_skills \
  https://github.com/mattpocock/skills \
  diagnosing-bugs \
  code-review \
  codebase-design \
  domain-modeling \
  grilling \
  grill-me \
  grill-with-docs \
  improve-codebase-architecture \
  research \
  resolving-merge-conflicts \
  handoff \
  teach

run_step "Official Sentry Codex plugin" \
  "${script_dir}/install-sentry-plugin.sh"

run_step "Codex SEO suite" \
  "${script_dir}/install-codex-seo.sh"

if [ "${#failures[@]}" -ne 0 ]; then
  printf '\nGlobal installer completed with %s failure(s):\n' \
    "${#failures[@]}" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi

printf '\nAll global installers completed successfully.\n'
