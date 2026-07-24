#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fragment_path="${script_dir}/local-workstation.zsh"
zshrc_path="${ZSHRC_PATH:-${HOME}/.zshrc}"
start_marker="# >>> dotfiles local workstation zsh >>>"
end_marker="# <<< dotfiles local workstation zsh <<<"

if [[ ! -f "${fragment_path}" ]]; then
  echo "Local workstation zsh fragment not found: ${fragment_path}" >&2
  exit 1
fi

managed_block="${start_marker}
if [[ -r \"${fragment_path}\" ]]; then
  source \"${fragment_path}\"
fi
${end_marker}"

zshrc_dir="$(dirname -- "${zshrc_path}")"
mkdir -p -- "${zshrc_dir}"

if [[ -e "${zshrc_path}" ]]; then
  file_mode="$(stat -c '%a' "${zshrc_path}")"
else
  file_mode="644"
  : >"${zshrc_path}"
fi

clean_tmp="$(mktemp)"
out_tmp="$(mktemp "${zshrc_dir}/.zshrc.XXXXXX")"
cleanup() {
  rm -f -- "${clean_tmp}" "${out_tmp}"
}
trap cleanup EXIT

awk -v start="${start_marker}" -v end="${end_marker}" '
  $0 == start { skipping = 1; next }
  $0 == end { skipping = 0; next }
  !skipping { print }
' "${zshrc_path}" >"${clean_tmp}"

cat "${clean_tmp}" >"${out_tmp}"
printf '%s\n' "${managed_block}" >>"${out_tmp}"

chmod "${file_mode}" "${out_tmp}"
mv -- "${out_tmp}" "${zshrc_path}"
trap - EXIT
rm -f -- "${clean_tmp}"

echo "Installed local workstation zsh setup into ${zshrc_path}."
