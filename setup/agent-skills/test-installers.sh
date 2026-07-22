#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
installer_dir="${1:-$script_dir}"
temporary_dir="$(mktemp -d)"
trap 'rm -rf -- "$temporary_dir"' EXIT

make_npx_stub() {
  local bin_dir="$1"
  cat >"${bin_dir}/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npx %s\n' "$*" >>"$TEST_LOG"
EOF
  chmod 700 "${bin_dir}/npx"
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
  chmod 700 "${bin_dir}/mise"
  make_npx_stub "$bin_dir"

  HOME="$home_dir" \
    XDG_CONFIG_HOME="${home_dir}/.config" \
    TEST_LOG="$log" \
    PATH="${bin_dir}:$PATH" \
    "${installer_dir}/install-activecollab.sh" >/dev/null

  grep -Fq 'mise age=0d latest github:microHoffman/activecollab-cli' "$log"
}

make_agent_browser_stubs() {
  local bin_dir="$1"

  cat >"${bin_dir}/node" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${TEST_NODE_MAJOR:-24}"
EOF
  chmod 700 "${bin_dir}/node"

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
chmod 700 "${prefix}/bin/agent-browser"
EOF
  chmod 700 "${bin_dir}/npm"

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
  chmod 700 "${bin_dir}/mise"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_NODE_MAJOR=24 \
    PATH="${bin_dir}:$PATH" \
    "${installer_dir}/install-agent-browser.sh"

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
  chmod 700 "${bin_dir}/mise"

  HOME="$home_dir" \
    TEST_LOG="$log" \
    TEST_NODE_MAJOR=20 \
    PATH="${bin_dir}:$PATH" \
    "${installer_dir}/install-agent-browser.sh"

  grep -Fq 'mise install node@24' "$log"
  grep -Fq 'mise exec node@24 -- npm install --global --prefix' "$log"
  if grep -Fq 'mise use ' "$log"; then
    printf 'agent-browser installer unexpectedly modified mise configuration\n' >&2
    exit 1
  fi
}

test_activecollab_release_age
test_agent_browser_user_prefix
test_agent_browser_mise_fallback
printf 'Installer regression checks passed.\n'
