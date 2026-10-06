#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
release_file="${script_dir}/release.json"
archive=""
install_root="${ORCA_INSTALL_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/orca-install}"
bin_dir="${ORCA_BIN_DIR:-${HOME}/.local/bin}"

usage() {
  cat <<'EOF'
Usage: install.sh [--archive APPIMAGE] [--release-file JSON]

Install the pinned Orca Linux release and orca-ide CLI without starting it.
--archive verifies and uses a previously downloaded AppImage.
--release-file selects reviewed release metadata for an intentional upgrade.
ORCA_INSTALL_ROOT and ORCA_BIN_DIR override the user-local destinations.
Stop Orca and back up its profile before upgrading; old releases are retained.
EOF
}

die() { printf 'orca-install: %s\n' "$*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive|--release-file)
      [ "$#" -ge 2 ] || die "$1 requires a path"
      case "$1" in
        --archive) archive="$2" ;;
        --release-file) release_file="$2" ;;
      esac
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

[ "$(uname -s)" = Linux ] || die 'this installer supports Linux; use the desktop download on macOS/Windows'
for command in jq curl sha256sum flock readlink mktemp; do
  command -v "$command" >/dev/null || die "missing command: $command"
done
architecture="$(uname -m)"
version="$(jq -er '.version' "$release_file")"
asset="$(jq -er --arg arch "$architecture" '.assets[$arch].name' "$release_file")"
checksum="$(jq -er --arg arch "$architecture" '.assets[$arch].sha256' "$release_file")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid release version'
[[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || die 'invalid SHA-256'
case "$architecture:$asset" in
  x86_64:orca-linux.AppImage|aarch64:orca-linux-arm64.AppImage) ;;
  *) die "unsupported architecture or asset: $architecture / $asset" ;;
esac
install_root="$(readlink -m -- "$install_root")"
bin_dir="$(readlink -m -- "$bin_dir")"
if [ -n "$archive" ]; then
  archive="$(readlink -f -- "$archive")"
  [ -f "$archive" ] || die "archive is not a regular file: $archive"
fi

if [ -d "$install_root" ] && [ ! -f "$install_root/.dotfiles-orca-install" ]; then
  [ -z "$(ls -A -- "$install_root")" ] || die "refusing an unrelated nonempty directory: $install_root"
fi
mkdir -p -- "$install_root" "$bin_dir"
exec 9>"$install_root/.install.lock"
flock 9
touch "$install_root/.dotfiles-orca-install"
mkdir -p -- "$install_root/releases"

cli="$bin_dir/orca-ide"
if [ -e "$cli" ] || [ -L "$cli" ]; then
  [ -L "$cli" ] || die "refusing to replace an unrelated executable: $cli"
  case "$(readlink -m -- "$cli")" in
    "$install_root"/releases/*/resources/bin/orca-ide) ;;
    *) die "refusing to replace an unrelated symlink: $cli" ;;
  esac
fi
if [ -e "$install_root/current" ] || [ -L "$install_root/current" ]; then
  [ -L "$install_root/current" ] || die 'current must be an installer-owned symlink'
  case "$(readlink -m -- "$install_root/current")" in
    "$install_root"/releases/*) ;;
    *) die 'current points outside the managed releases' ;;
  esac
fi

stage="$(mktemp -d "$install_root/.stage.XXXXXX")"
link_stage="$(mktemp -d "$bin_dir/.orca-link.XXXXXX")"
trap 'rm -rf -- "$stage" "$link_stage"' EXIT
release_dir="$install_root/releases/$version"
if [ ! -e "$release_dir" ]; then
  if [ -n "$archive" ]; then
    cp -- "$archive" "$stage/orca.AppImage"
  else
    curl --fail --location --retry 3 \
      "https://github.com/stablyai/orca/releases/download/v${version}/${asset}" \
      --output "$stage/orca.AppImage"
  fi
  printf '%s  %s\n' "$checksum" "$stage/orca.AppImage" | sha256sum --check --status \
    || die 'AppImage checksum mismatch; installation was not changed'
  chmod 700 "$stage/orca.AppImage"
  (cd "$stage" && ./orca.AppImage --appimage-extract >extract.log)
  extracted="$stage/squashfs-root"
  [ -x "$extracted/AppRun" ] && [ -x "$extracted/resources/bin/orca-ide" ] \
    || die 'release is missing AppRun or its bundled CLI'
  [ "$("$extracted/resources/bin/orca-ide" --version)" = "$version" ] \
    || die 'bundled CLI version does not match release metadata'
  printf '%s\n' "$checksum" >"$extracted/.release.sha256"
  mv -- "$extracted" "$release_dir"
else
  [ -f "$release_dir/.release.sha256" ] \
    && [ "$(cat "$release_dir/.release.sha256")" = "$checksum" ] \
    || die 'existing release does not match the selected checksum'
  [ "$("$release_dir/resources/bin/orca-ide" --version)" = "$version" ] \
    || die 'existing release failed its CLI version check'
fi

ln -s "releases/$version" "$stage/current"
ln -s "$install_root/current/resources/bin/orca-ide" "$link_stage/orca-ide"
mv -Tf -- "$stage/current" "$install_root/current"
mv -Tf -- "$link_stage/orca-ide" "$cli"
printf 'Installed Orca %s at %s\nCLI: %s\n' "$version" "$release_dir" "$cli"
printf 'Runtime not started. See setup/orca/README.md for service setup and pairing.\n'
