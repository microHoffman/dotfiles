#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--update] [--yes] codex|aoe|codex-acp [tool ...]\n' "${0##*/}" >&2
  printf '  --update  Install the pinned Codex version even if Codex already exists (Codex only).\n' >&2
  printf '  --yes     Run the checksum-verified Codex installer without the review prompt (Codex only).\n' >&2
}

update=false
assume_yes=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --update) update=true; shift ;;
    --yes) assume_yes=true; shift ;;
    *) break ;;
  esac
done
if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi
for requested_tool in "$@"; do
  case "$requested_tool" in
    codex) ;;
    aoe|codex-acp)
      if "$update" || "$assume_yes"; then
        usage
        exit 2
      fi ;;
    *) usage; exit 2 ;;
  esac
done

temporary_dir="$(mktemp -d)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cleanup() {
  rm -rf -- "$temporary_dir"
}
trap cleanup EXIT

install_tool() {
  tool="$1"
  url="$2"
  installer="${temporary_dir}/${tool}-install.sh"

  if ! "$update" && command -v "$tool" >/dev/null 2>&1; then
    printf '%s is already installed; preserving it:\n' "$tool"
    "$tool" --version
    return
  fi

  curl -fsSL "$url" -o "$installer"
  chmod 600 "$installer"
  printf '\nDownloaded the official %s installer to %s\n' "$tool" "$installer"
  sha256sum "$installer"
  if [ "$tool" = codex ]; then
    expected_hash="$(jq -er .installerSha256 "${script_dir}/codex-release.json")"
    printf '%s  %s\n' "$expected_hash" "$installer" | sha256sum --check --status
  fi
  if ! "$assume_yes"; then
    printf 'Review the installer before continuing.\n'
    "${PAGER:-less}" "$installer"
    read -r -p "Type INSTALL-${tool} to execute it: " confirmation
    if [ "$confirmation" != "INSTALL-${tool}" ]; then
      printf 'Skipped %s installation.\n' "$tool"
      return
    fi
  fi

  if [ "$tool" = codex ]; then
    version="$(jq -er .version "${script_dir}/codex-release.json")"
    CODEX_NON_INTERACTIVE=true bash "$installer" --release "$version"
  else
    bash "$installer"
  fi
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
      install_tool codex "$(jq -er .installerUrl "${script_dir}/codex-release.json")"
      ;;
    aoe)
      install_tool aoe "https://raw.githubusercontent.com/agent-of-empires/agent-of-empires/main/scripts/install.sh"
      ;;
    codex-acp)
      "${script_dir}/../codex-acp/install.sh"
      ;;
    *)
      printf 'Unknown tool: %s\n' "$requested_tool" >&2
      usage
      exit 2
      ;;
  esac
done
