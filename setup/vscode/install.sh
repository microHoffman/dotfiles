#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
extensions_file="${script_dir}/extensions.txt"
settings_fragment="${script_dir}/settings.json"

code_bin="${CODE_BIN:-code}"

if ! command -v "${code_bin}" >/dev/null 2>&1; then
  echo "Could not find '${code_bin}' on PATH. Set CODE_BIN to your VS Code CLI binary." >&2
  exit 1
fi

while IFS= read -r extension || [[ -n "${extension}" ]]; do
  [[ -z "${extension}" || "${extension}" =~ ^[[:space:]]*# ]] && continue
  "${code_bin}" --install-extension "${extension}"
done <"${extensions_file}"

if [[ -n "${VSCODE_USER_DIR:-}" ]]; then
  user_dir="${VSCODE_USER_DIR}"
else
  case "$(uname -s)" in
    Linux*)
      user_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User"
      ;;
    Darwin*)
      user_dir="${HOME}/Library/Application Support/Code/User"
      ;;
    CYGWIN* | MINGW* | MSYS*)
      user_dir="${APPDATA:-${HOME}/AppData/Roaming}/Code/User"
      ;;
    *)
      echo "Could not infer VS Code user settings directory for this platform." >&2
      echo "Set VSCODE_USER_DIR to the directory containing settings.json." >&2
      exit 1
      ;;
  esac
fi

settings_file="${user_dir}/settings.json"

if ! command -v node >/dev/null 2>&1; then
  echo "Installed extensions, but could not merge settings because node is missing." >&2
  echo "Manually merge ${settings_fragment} into ${settings_file}." >&2
  exit 1
fi

node "${script_dir}/merge-settings.mjs" "${settings_file}" "${settings_fragment}"

echo "VS Code extensions installed and settings merged into ${settings_file}."
