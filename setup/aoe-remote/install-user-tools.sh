#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s codex|aoe [codex|aoe ...]\n' "${0##*/}" >&2
}

if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi

temporary_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

install_tool() {
  tool="$1"
  url="$2"
  installer="${temporary_dir}/${tool}-install.sh"

  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s is already installed; preserving it:\n' "$tool"
    "$tool" --version
    return
  fi

  curl -fsSL "$url" -o "$installer"
  chmod 600 "$installer"
  printf '\nDownloaded the official %s installer to %s\n' "$tool" "$installer"
  sha256sum "$installer"
  printf 'Review the installer before continuing.\n'
  "${PAGER:-less}" "$installer"
  read -r -p "Type INSTALL-${tool} to execute it: " confirmation
  if [ "$confirmation" != "INSTALL-${tool}" ]; then
    printf 'Skipped %s installation.\n' "$tool"
    return
  fi

  bash "$installer"
  hash -r
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s installed, but it is not on PATH in this shell yet. Start a new shell and verify it.\n' "$tool"
    return
  fi
  "$tool" --version
}

for requested_tool in "$@"; do
  case "$requested_tool" in
    codex)
      install_tool codex "https://chatgpt.com/codex/install.sh"
      ;;
    aoe)
      install_tool aoe "https://raw.githubusercontent.com/agent-of-empires/agent-of-empires/main/scripts/install.sh"
      ;;
    *)
      printf 'Unknown tool: %s\n' "$requested_tool" >&2
      usage
      exit 2
      ;;
  esac
done
