#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s /path/to/codex-acp/install.sh\n' "${0##*/}" >&2
  exit 2
fi

installer="$1"
temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

fake_bin="${temporary_dir}/bin"
mkdir -p -- "$fake_bin"

{
  printf '#!%s\n' "$BASH"
  cat <<'SH'
set -euo pipefail
printf '%s\n' "${FAKE_NODE_VERSION:?}"
SH
} >"${fake_bin}/node"

{
  printf '#!%s\n' "$BASH"
  cat <<'SH'
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_NPM_LOG:?}"

prefix=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      prefix="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ "${FAKE_NPM_SKIP_BINARY:-false}" = true ]; then
  exit 0
fi

mkdir -p -- "${prefix:?}/bin"
{
  printf '#!%s\n' "$BASH"
  cat <<'BIN'
set -euo pipefail
printf 'codex-acp %s\n' "${FAKE_CODEX_ACP_VERSION:-test}"
BIN
} >"${prefix}/bin/codex-acp"
chmod +x -- "${prefix}/bin/codex-acp"
SH
} >"${fake_bin}/npm"

chmod +x -- "${fake_bin}/node" "${fake_bin}/npm"

export PATH="${fake_bin}:${PATH}"
export FAKE_NPM_LOG="${temporary_dir}/npm.log"
export FAKE_CODEX_ACP_VERSION="1.2.3"

old_node_home="${temporary_dir}/old-node-home"
mkdir -p -- "$old_node_home"
if HOME="$old_node_home" FAKE_NODE_VERSION="v18.20.0" bash "$installer"; then
  printf 'expected Node.js 18 installation to fail\n' >&2
  exit 1
fi
test ! -e "$FAKE_NPM_LOG"

install_home="${temporary_dir}/install-home"
mkdir -p -- "$install_home"
HOME="$install_home" FAKE_NODE_VERSION="v20.0.0" bash "$installer"
test -x "${install_home}/.local/bin/codex-acp"
grep -Fxq \
  "install --global --prefix ${install_home}/.local @agentclientprotocol/codex-acp@latest" \
  "$FAKE_NPM_LOG"

line_count="$(wc -l <"$FAKE_NPM_LOG")"
HOME="$install_home" FAKE_NODE_VERSION="v24.18.0" bash "$installer"
test "$(wc -l <"$FAKE_NPM_LOG")" = "$line_count"

HOME="$install_home" FAKE_NODE_VERSION="v24.18.0" \
  bash "$installer" --update
test "$(wc -l <"$FAKE_NPM_LOG")" = "$((line_count + 1))"

missing_binary_home="${temporary_dir}/missing-binary-home"
mkdir -p -- "$missing_binary_home"
if HOME="$missing_binary_home" \
  FAKE_NODE_VERSION="v24.18.0" \
  FAKE_NPM_SKIP_BINARY=true \
  bash "$installer"; then
  printf 'expected a missing installed binary to fail verification\n' >&2
  exit 1
fi

printf 'codex-acp installer tests passed\n'
