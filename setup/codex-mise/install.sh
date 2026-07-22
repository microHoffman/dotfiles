#!/usr/bin/env bash
set -euo pipefail

zshenv_path="${ZSHENV_PATH:-${HOME}/.zshenv}"
start_marker="# >>> dotfiles codex mise shims >>>"
end_marker="# <<< dotfiles codex mise shims <<<"

managed_block="$(cat <<'EOF'
# >>> dotfiles codex mise shims >>>
# Make mise-managed tools available to Codex command shells without full shell activation.
if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ] || [ -n "${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then
  mise_shims="${MISE_SHIMS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims}"
  if [ -d "$mise_shims" ]; then
    typeset -U path
    path=("$HOME/.local/bin" "$mise_shims" $path)
    export PATH
  fi
fi
# <<< dotfiles codex mise shims <<<
EOF
)"

zshenv_dir="$(dirname -- "$zshenv_path")"
mkdir -p -- "$zshenv_dir"

if [[ -e "$zshenv_path" ]]; then
  file_mode="$(stat -c '%a' "$zshenv_path")"
else
  file_mode="644"
  : >"$zshenv_path"
fi

clean_tmp="$(mktemp)"
out_tmp="$(mktemp "${zshenv_dir}/.zshenv.XXXXXX")"
cleanup() {
  rm -f -- "$clean_tmp" "$out_tmp"
}
trap cleanup EXIT

awk -v start="$start_marker" -v end="$end_marker" '
  $0 == start { skipping = 1; next }
  $0 == end { skipping = 0; next }
  !skipping { print }
' "$zshenv_path" >"$clean_tmp"

if [[ -s "$clean_tmp" ]]; then
  cat "$clean_tmp" >"$out_tmp"
  printf '\n%s\n' "$managed_block" >>"$out_tmp"
else
  printf '%s\n' "$managed_block" >"$out_tmp"
fi

chmod "$file_mode" "$out_tmp"
mv -- "$out_tmp" "$zshenv_path"
trap - EXIT
rm -f -- "$clean_tmp"

echo "Installed Codex mise shim setup into ${zshenv_path}."
