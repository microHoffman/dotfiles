#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${script_dir}/_lib.sh"

printf '\n==> ActiveCollab CLI and skill\n'
"${script_dir}/install-activecollab.sh"

printf '\n==> agent-browser CLI, browser, and skill\n'
"${script_dir}/install-agent-browser.sh"

printf '\n==> microHoffman agent skills\n'
install_global_skills \
  https://github.com/microHoffman/agent-skills \
  create-pull-request \
  github-issues \
  gitlab-create-mr

printf '\n==> OpenZeppelin smart-contract skills\n'
install_global_skills \
  https://github.com/OpenZeppelin/openzeppelin-skills \
  develop-secure-contracts \
  upgrade-solidity-contracts

printf '\n==> Matt Pocock engineering and productivity skills\n'
install_global_skills \
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

printf '\n==> Explicit-only Sentry fix workflow\n'
"${script_dir}/install-sentry-fix-issues.sh"

printf '\n==> Codex SEO suite\n'
"${script_dir}/install-codex-seo.sh"
