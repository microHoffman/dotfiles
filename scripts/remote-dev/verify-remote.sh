#!/usr/bin/env bash
set -u

failures=0
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

check() {
  label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "${label}"
  else
    printf 'fail %s\n' "${label}"
    failures=$((failures + 1))
  fi
}

check "nixos-rebuild is available" command -v nixos-rebuild
check "home directory exists" test -d "${HOME}"
check "tmux is available" command -v tmux
check "docker daemon responds" docker info
check "docker compose is available" docker compose version
check "tailscale is available" command -v tailscale
check "tailscale has a status" tailscale status
check "direnv is available" command -v direnv
check "node is available" command -v node
check "bun is available" command -v bun
check "uv is available" command -v uv
check "rustup is available" command -v rustup
check "Rust toolchain is active" rustup show active-toolchain
check "rustc is runnable" rustc --version
check "cargo is runnable" cargo --version
check "mise is available" command -v mise
check "Foundry forge is available" command -v forge
check "Foundry cast is available" command -v cast
check "Foundry anvil is available" command -v anvil
check "Foundry chisel is available" command -v chisel
check "psql is available" command -v psql
check "mysql client is available" command -v mysql
check "redis-cli is available" command -v redis-cli
check "sqlite3 is available" command -v sqlite3

if [ "${REMOTE_DEV_VERIFY_AOE:-0}" = "1" ]; then
  printf '\nAoE/Codex verification:\n'
  if ! "${script_dir}/verify-aoe.sh"; then
    failures=$((failures + 1))
  fi
fi

if [ "${failures}" -ne 0 ]; then
  printf '\n%s checks failed.\n' "${failures}" >&2
  exit 1
fi
