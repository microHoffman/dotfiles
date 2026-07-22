#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
installer_dir="${1:-$script_dir}"
temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

make_executable() {
  local path="$1"
  sed -i "1s|.*|#!${BASH}|" "$path"
  chmod 700 "$path"
}

make_npx_stub() {
  local bin_dir="$1"
  cat >"${bin_dir}/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npx %s\n' "$*" >>"$TEST_LOG"
EOF
  make_executable "${bin_dir}/npx"
}

make_sentry_stubs() {
  local bin_dir="$1"

  cat >"${bin_dir}/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'codex %s\n' "$*" >>"$TEST_LOG"
case "$*" in
  "plugin marketplace list --json")
    printf '%s\n' "$TEST_MARKETPLACE_JSON"
    ;;
  "plugin list --json")
    printf '%s\n' "$TEST_PLUGIN_JSON"
    ;;
esac
EOF
  make_executable "${bin_dir}/codex"

  cat >"${bin_dir}/reconcile-managed-agent-configs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'reconcile-managed-agent-configs\n' >>"$TEST_LOG"
if [ "${TEST_RECONCILE_FAIL:-0}" = "1" ]; then
  exit 1
fi
EOF
  make_executable "${bin_dir}/reconcile-managed-agent-configs"

  cat >"${bin_dir}/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npx %s\n' "$*" >>"$TEST_LOG"
if [[ " $* " == *" remove "* ]] && [[ " $* " == *" sentry-fix-issues "* ]]; then
  rm -rf -- "$HOME/.agents/skills/sentry-fix-issues"
  python3 - "$HOME/.agents/.skill-lock.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.get("skills", {}).pop("sentry-fix-issues", None)
path.write_text(json.dumps(data))
PY
fi
EOF
  make_executable "${bin_dir}/npx"
}

make_legacy_sentry_skill() {
  local home_dir="$1"

  mkdir -p "${home_dir}/.agents/skills/sentry-fix-issues"
  printf '%s\n' 'legacy' >"${home_dir}/.agents/skills/sentry-fix-issues/SKILL.md"
  cat >"${home_dir}/.agents/.skill-lock.json" <<'JSON'
{
  "skills": {
    "sentry-fix-issues": {
      "source": "getsentry/sentry-agent-skills",
      "skillPath": "skills/sentry-fix-issues/SKILL.md"
    }
  }
}
JSON
}

test_activecollab_release_age() {
  local case_dir="${temporary_dir}/activecollab"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"

  cat >"${bin_dir}/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mise age=%s %s\n' "${MISE_MINIMUM_RELEASE_AGE:-unset}" "$*" >>"$TEST_LOG"
case "$1" in
  latest)
    test "${MISE_MINIMUM_RELEASE_AGE:-}" = "0d"
    printf '0.3.0\n'
    ;;
  use)
    ;;
  exec)
    printf '{"version":"0.3.0"}\n'
    ;;
  *)
    exit 1
    ;;
esac
EOF
  make_executable "${bin_dir}/mise"
  make_npx_stub "$bin_dir"

  HOME="$home_dir" \
    XDG_CONFIG_HOME="${home_dir}/.config" \
    TEST_LOG="$log" \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-activecollab.sh" >/dev/null

  grep -Fq 'mise age=0d latest github:microHoffman/activecollab-cli' "$log"
}

make_agent_browser_stubs() {
  local bin_dir="$1"

  cat >"${bin_dir}/node" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${TEST_NODE_MAJOR:-24}"
EOF
  make_executable "${bin_dir}/node"

  cat >"${bin_dir}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %s\n' "$*" >>"$TEST_LOG"
prefix=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--prefix" ]; then
    prefix="$2"
    break
  fi
  shift
done
test -n "$prefix"
mkdir -p "${prefix}/bin"
cat >"${prefix}/bin/agent-browser" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'agent-browser %s\n' "$*" >>"$TEST_LOG"
SCRIPT
sed -i "1s|.*|#!${BASH}|" "${prefix}/bin/agent-browser"
chmod 700 "${prefix}/bin/agent-browser"
EOF
  make_executable "${bin_dir}/npm"

  make_npx_stub "$bin_dir"
}

test_agent_browser_user_prefix() {
  local case_dir="${temporary_dir}/agent-browser-native"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_agent_browser_stubs "$bin_dir"

  cat >"${bin_dir}/mise" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  make_executable "${bin_dir}/mise"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_NODE_MAJOR=24 \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-agent-browser.sh"

  grep -Fq "npm install --global --prefix ${home_dir}/.local agent-browser@latest" "$log"
  grep -Fq 'agent-browser install' "$log"
  if grep -Fq 'mise ' "$log"; then
    printf 'agent-browser installer unexpectedly used mise with Node 24\n' >&2
    exit 1
  fi
}

test_agent_browser_mise_fallback() {
  local case_dir="${temporary_dir}/agent-browser-mise"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_agent_browser_stubs "$bin_dir"

  cat >"${bin_dir}/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mise %s\n' "$*" >>"$TEST_LOG"
case "$1" in
  install)
    test "$2" = "node@24"
    ;;
  exec)
    shift
    test "$1" = "node@24"
    shift
    test "$1" = "--"
    shift
    if [ "$1" = "node" ]; then
      printf '24\n'
    elif [ "$1" = "npm" ]; then
      shift
      npm "$@"
    else
      exit 1
    fi
    ;;
  *)
    exit 1
    ;;
esac
EOF
  make_executable "${bin_dir}/mise"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_NODE_MAJOR=20 \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-agent-browser.sh"

  grep -Fq 'mise install node@24' "$log"
  grep -Fq 'mise exec node@24 -- npm install --global --prefix' "$log"
  if grep -Fq 'mise use ' "$log"; then
    printf 'agent-browser installer unexpectedly modified mise configuration\n' >&2
    exit 1
  fi
}

test_sentry_plugin_fresh_install_and_cleanup() {
  local case_dir="${temporary_dir}/sentry-fresh"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_sentry_stubs "$bin_dir"
  make_legacy_sentry_skill "$home_dir"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_MARKETPLACE_JSON='{"marketplaces":[]}' \
    TEST_PLUGIN_JSON='{"installed":[{"pluginId":"sentry@sentry-plugin-marketplace","installed":true},{"pluginId":"sentry@openai-curated","installed":true}],"available":[]}' \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-sentry-plugin.sh" >/dev/null

  grep -Fq 'codex plugin marketplace add getsentry/plugin-codex' "$log"
  grep -Fq 'codex plugin add sentry@sentry-plugin-marketplace' "$log"
  grep -Fq 'codex plugin remove sentry@openai-curated' "$log"
  grep -Fq "npx -y skills@latest remove --global --agent * --yes sentry-fix-issues" "$log"
  test "$(grep -Fc 'reconcile-managed-agent-configs' "$log")" = "1"
  test ! -e "${home_dir}/.agents/skills/sentry-fix-issues"
}

test_sentry_plugin_existing_marketplace_upgrade() {
  local case_dir="${temporary_dir}/sentry-upgrade"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_sentry_stubs "$bin_dir"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_MARKETPLACE_JSON='{"marketplaces":[{"name":"sentry-plugin-marketplace","root":"/tmp/sentry","marketplaceSource":{"sourceType":"git","source":"https://github.com/getsentry/plugin-codex.git"}}]}' \
    TEST_PLUGIN_JSON='{"installed":[{"pluginId":"sentry@sentry-plugin-marketplace","installed":true}],"available":[]}' \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-sentry-plugin.sh" >/dev/null

  grep -Fq 'codex plugin marketplace upgrade sentry-plugin-marketplace' "$log"
  if grep -Fq 'codex plugin marketplace add' "$log"; then
    printf 'Sentry installer unexpectedly added an existing marketplace\n' >&2
    exit 1
  fi
}

test_sentry_plugin_rejects_marketplace_mismatch() {
  local case_dir="${temporary_dir}/sentry-mismatch"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_sentry_stubs "$bin_dir"

  if HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_MARKETPLACE_JSON='{"marketplaces":[{"name":"sentry-plugin-marketplace","root":"/tmp/sentry","marketplaceSource":{"sourceType":"git","source":"https://github.com/example/not-sentry"}}]}' \
    TEST_PLUGIN_JSON='{"installed":[],"available":[]}' \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-sentry-plugin.sh" >/dev/null 2>&1; then
    printf 'expected Sentry installer to reject a marketplace source mismatch\n' >&2
    exit 1
  fi

  if grep -Fq 'codex plugin add' "$log"; then
    printf 'Sentry installer mutated plugin state after a source mismatch\n' >&2
    exit 1
  fi
}

test_sentry_plugin_retries_failed_reconciliation_on_exit() {
  local case_dir="${temporary_dir}/sentry-reconcile-failure"
  local bin_dir="${case_dir}/bin"
  local home_dir="${case_dir}/home"
  local log="${case_dir}/calls.log"
  mkdir -p "$bin_dir" "$home_dir"
  : >"$log"
  make_sentry_stubs "$bin_dir"

  if HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_RECONCILE_FAIL=1 \
    TEST_MARKETPLACE_JSON='{"marketplaces":[]}' \
    TEST_PLUGIN_JSON='{"installed":[{"pluginId":"sentry@sentry-plugin-marketplace","installed":true}],"available":[]}' \
    PATH="${bin_dir}:$PATH" \
    bash "${installer_dir}/install-sentry-plugin.sh" >/dev/null 2>&1; then
    printf 'expected Sentry installer to fail when reconciliation fails\n' >&2
    exit 1
  fi

  test "$(grep -Fc 'reconcile-managed-agent-configs' "$log")" = "2"
}

test_activecollab_release_age
test_agent_browser_user_prefix
test_agent_browser_mise_fallback
test_sentry_plugin_fresh_install_and_cleanup
test_sentry_plugin_existing_marketplace_upgrade
test_sentry_plugin_rejects_marketplace_mismatch
test_sentry_plugin_retries_failed_reconciliation_on_exit
printf 'Installer regression checks passed.\n'
