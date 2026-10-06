#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
installer="${1:-$script_dir/install.sh}"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

make_executable() {
  sed -i "1s|.*|#!${BASH}|" "$1"
  chmod 700 "$1"
}

cat >"$test_root/bin/uname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -s) printf 'Linux\n' ;;
  -m) printf '%s\n' "${TEST_ARCH:-x86_64}" ;;
  *) exit 1 ;;
esac
EOF
cat >"$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'download\n' >>"$TEST_DOWNLOAD_LOG"
output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then output="$2"; shift; fi
  shift
done
cp "$TEST_ARCHIVE" "$output"
EOF
make_executable "$test_root/bin/uname"
make_executable "$test_root/bin/curl"
export PATH="$test_root/bin:$PATH"
export TEST_DOWNLOAD_LOG="$test_root/downloads"
export ORCA_INSTALL_ROOT="$test_root/install"
export ORCA_BIN_DIR="$test_root/user-bin"
: >"$TEST_DOWNLOAD_LOG"

make_release() {
  local version="$1"
  cat >"$test_root/$version.AppImage" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = --appimage-extract ]
[ "${TEST_EXTRACT_FAIL:-0}" != 1 ] || exit 1
mkdir -p squashfs-root/resources/bin
printf '#!%s\nexit 0\n' "$BASH" >squashfs-root/AppRun
printf '#!%s\n[ "${TEST_CLI_FAIL:-0}" != 1 ] || exit 1\nprintf "@VERSION@\\n"\n' "$BASH" >squashfs-root/resources/bin/orca-ide
chmod 700 squashfs-root/AppRun squashfs-root/resources/bin/orca-ide
EOF
  sed -i "s/@VERSION@/$version/g" "$test_root/$version.AppImage"
  make_executable "$test_root/$version.AppImage"
  local checksum
  checksum="$(sha256sum "$test_root/$version.AppImage")"
  jq -n --arg version "$version" --arg hash "${checksum%% *}" \
    '{version: $version, assets: {x86_64: {name: "orca-linux.AppImage", sha256: $hash}}}' \
    >"$test_root/$version.json"
}

expect_failure() {
  if "$@" >"$test_root/failure.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2
    exit 1
  fi
}

make_release 1.0.0
make_release 1.0.1
export TEST_ARCHIVE="$test_root/1.0.0.AppImage"
bash "$installer" --release-file "$test_root/1.0.0.json" >/dev/null
[ "$("$ORCA_BIN_DIR/orca-ide" --version)" = 1.0.0 ]
[ "$(wc -l <"$TEST_DOWNLOAD_LOG")" -eq 1 ]
bash "$installer" --release-file "$test_root/1.0.0.json" >/dev/null
[ "$(wc -l <"$TEST_DOWNLOAD_LOG")" -eq 1 ]
printf 'ok   initial installation and idempotent rerun\n'

export TEST_ARCHIVE="$test_root/1.0.1.AppImage"
jq '.assets.x86_64.sha256 = ("0" * 64)' "$test_root/1.0.1.json" >"$test_root/bad.json"
expect_failure bash "$installer" --release-file "$test_root/bad.json"
[ "$(readlink "$ORCA_INSTALL_ROOT/current")" = releases/1.0.0 ]
[ ! -e "$ORCA_INSTALL_ROOT/releases/1.0.1" ]
printf 'ok   checksum mismatch preserves the active release\n'

expect_failure env TEST_EXTRACT_FAIL=1 bash "$installer" --release-file "$test_root/1.0.1.json"
expect_failure env TEST_CLI_FAIL=1 bash "$installer" --release-file "$test_root/1.0.1.json"
[ "$(readlink "$ORCA_INSTALL_ROOT/current")" = releases/1.0.0 ]
[ ! -e "$ORCA_INSTALL_ROOT/releases/1.0.1" ]
printf 'ok   extraction and CLI validation failures preserve the active release\n'

bash "$installer" --release-file "$test_root/1.0.1.json" --archive "$TEST_ARCHIVE" >/dev/null
[ "$("$ORCA_BIN_DIR/orca-ide" --version)" = 1.0.1 ]
[ -x "$ORCA_INSTALL_ROOT/releases/1.0.0/resources/bin/orca-ide" ]
printf 'ok   verified local archive upgrade retains the old release\n'

rm "$ORCA_BIN_DIR/orca-ide"
printf 'unrelated executable\n' >"$ORCA_BIN_DIR/orca-ide"
expect_failure bash "$installer" --release-file "$test_root/1.0.1.json"
grep -qx 'unrelated executable' "$ORCA_BIN_DIR/orca-ide"
rm "$ORCA_BIN_DIR/orca-ide"
ln -s "$test_root/unrelated" "$ORCA_BIN_DIR/orca-ide"
expect_failure bash "$installer" --release-file "$test_root/1.0.1.json"
[ "$(readlink "$ORCA_BIN_DIR/orca-ide")" = "$test_root/unrelated" ]
printf 'ok   unrelated executable and symlink are preserved\n'

expect_failure env TEST_ARCH=unsupported bash "$installer" --release-file "$test_root/1.0.1.json"
mkdir "$test_root/unrelated-root"
touch "$test_root/unrelated-root/keep"
expect_failure env ORCA_INSTALL_ROOT="$test_root/unrelated-root" bash "$installer" --release-file "$test_root/1.0.1.json"
[ -f "$test_root/unrelated-root/keep" ]
printf 'ok   unsupported architecture and unrelated destination rejected\n'
