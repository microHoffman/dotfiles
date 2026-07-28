#!/usr/bin/env bash
set -uo pipefail

swap_file="/var/swap/swapfile"
lid_config="/etc/systemd/logind.conf.d/50-hibernate-on-lid.conf"
kernel="$(uname -r)"
initramfs="/boot/initramfs-${kernel}.img"
failures=0
warnings=0

pass() {
  printf 'PASS: %s\n' "$*"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
  warnings=$((warnings + 1))
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this read-only verifier with sudo." >&2
  exit 2
fi

echo "Fedora hibernation verification"
echo "Kernel: ${kernel}"
cat /etc/fedora-release
systemctl --version | sed -n '1p'
dracut --version
echo

if [[ -d /sys/firmware/efi ]]; then
  pass "system booted through UEFI"
else
  fail "system did not boot through UEFI"
fi

secure_boot="$(mokutil --sb-state 2>&1 || true)"
echo "${secure_boot}"
if grep -q 'SecureBoot disabled' <<<"${secure_boot}"; then
  pass "Secure Boot is disabled"
else
  warn "Secure Boot is not reported disabled; verify hibernation lockdown policy"
fi

lockdown="$(cat /sys/kernel/security/lockdown 2>/dev/null || true)"
echo "Kernel lockdown: ${lockdown:-unavailable}"
if [[ "${lockdown}" == *"[none]"* ]]; then
  pass "kernel lockdown is disabled"
else
  warn "kernel lockdown is not disabled or could not be read"
fi

power_states="$(cat /sys/power/state)"
if grep -qw disk <<<"${power_states}"; then
  pass "kernel exposes the disk hibernation state"
else
  fail "kernel does not expose the disk hibernation state"
fi
echo "/sys/power/state: ${power_states}"
echo "/sys/power/disk: $(cat /sys/power/disk)"
echo "/sys/power/mem_sleep: $(cat /sys/power/mem_sleep)"
echo "/sys/power/image_size: $(cat /sys/power/image_size)"

if swapon --show=NAME --noheadings | grep -qx '/dev/zram0'; then
  pass "zram remains active"
else
  warn "zram is not active"
fi

if swapon --show=NAME --noheadings | grep -qx "${swap_file}"; then
  pass "disk-backed swap file is active"
else
  fail "disk-backed swap file is not active"
fi
swapon --show=NAME,TYPE,SIZE,USED,PRIO,UUID,LABEL

if [[ -f "${swap_file}" ]]; then
  mode="$(stat -c '%a' "${swap_file}")"
  owner="$(stat -c '%U:%G' "${swap_file}")"
  size="$(stat -c '%s' "${swap_file}")"
  memory_bytes="$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo)"

  [[ "${mode}" == "600" ]] && pass "swap file mode is 600" ||
    fail "swap file mode is ${mode}, expected 600"
  [[ "${owner}" == "root:root" ]] && pass "swap file is owned by root" ||
    fail "swap file owner is ${owner}, expected root:root"
  awk -v size="${size}" -v memory="${memory_bytes}" \
    'BEGIN { exit !(size >= memory) }' &&
    pass "swap file is at least as large as physical RAM" ||
    warn "swap file is smaller than physical RAM"

  attributes="$(lsattr -d "${swap_file}" 2>/dev/null || true)"
  [[ "${attributes%% *}" == *C* ]] && pass "swap file has No_COW set" ||
    fail "swap file does not show the No_COW attribute"

  if offset="$(btrfs inspect-internal map-swapfile -r "${swap_file}" 2>/dev/null)" &&
    [[ "${offset}" =~ ^[0-9]+$ ]]; then
    pass "Btrfs resume offset resolves to ${offset}"
  else
    fail "Btrfs could not resolve a valid resume offset"
  fi
else
  fail "${swap_file} does not exist"
fi

root_source="$(findmnt -no SOURCE / | sed 's/\[.*//')"
root_fstype="$(findmnt -no FSTYPE /)"
echo "Root: ${root_source} (${root_fstype})"
[[ "${root_fstype}" == "btrfs" ]] && pass "root filesystem is Btrfs" ||
  fail "root filesystem is not Btrfs"
[[ "${root_source}" == /dev/mapper/* ]] &&
  pass "root and swap are on a device-mapper mapping" ||
  fail "root is not on a device-mapper mapping"

if [[ "${root_source}" == /dev/mapper/* ]]; then
  crypt_status="$(cryptsetup status "${root_source}" 2>&1 || true)"
  echo "${crypt_status}"
  grep -q 'type:.*LUKS2' <<<"${crypt_status}" &&
    pass "root mapping is LUKS2" ||
    fail "root mapping is not reported as LUKS2"
fi

fstab_line='/var/swap/swapfile none swap defaults 0 0'
grep -qxF "${fstab_line}" /etc/fstab &&
  pass "fstab contains the expected swap entry" ||
  fail "fstab does not contain the expected swap entry"

grep -qxF 'add_dracutmodules+=" resume "' /etc/dracut.conf.d/resume.conf \
  2>/dev/null &&
  pass "dracut resume drop-in is installed" ||
  fail "dracut resume drop-in is missing or unexpected"

if [[ -r "${initramfs}" ]]; then
  modules="$(lsinitrd -m "${initramfs}" 2>/dev/null || true)"
  grep -qx resume <<<"${modules}" &&
    pass "running kernel initramfs contains the resume module" ||
    fail "running kernel initramfs lacks the resume module"

  initramfs_listing="$(mktemp)"
  trap 'rm -f -- "${initramfs_listing}"' EXIT
  lsinitrd "${initramfs}" >"${initramfs_listing}"
  grep -q 'systemd-hibernate-resume-generator' "${initramfs_listing}" &&
    pass "initramfs contains the systemd hibernate resume generator" ||
    fail "initramfs lacks the systemd hibernate resume generator"
  grep -q 'systemd-cryptsetup' "${initramfs_listing}" &&
    pass "initramfs contains LUKS unlock support" ||
    fail "initramfs lacks systemd-cryptsetup"
else
  fail "cannot read ${initramfs}"
fi

can_hibernate="$(busctl call org.freedesktop.login1 \
  /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate \
  2>/dev/null || true)"
[[ "${can_hibernate}" == 's "yes"' ]] &&
  pass "systemd reports CanHibernate=yes" ||
  fail "systemd reports CanHibernate=${can_hibernate:-unavailable}"

if [[ -r "${lid_config}" ]]; then
  grep -qxF 'HandleLidSwitch=hibernate' "${lid_config}" &&
    pass "lid close on battery is configured to hibernate" ||
    fail "lid close on battery has an unexpected policy"
  grep -qxF 'HandleLidSwitchExternalPower=hibernate' "${lid_config}" &&
    pass "lid close on external power is configured to hibernate" ||
    fail "lid close on external power has an unexpected policy"
  grep -qxF 'HandleLidSwitchDocked=ignore' "${lid_config}" &&
    pass "lid close while docked is configured to be ignored" ||
    fail "lid close while docked has an unexpected policy"
else
  warn "automatic lid hibernation is not configured"
fi

default_kernel="$(grubby --default-kernel 2>/dev/null || true)"
echo "Running kernel: /boot/vmlinuz-${kernel}"
echo "Default kernel: ${default_kernel:-unavailable}"
[[ "${default_kernel}" == "/boot/vmlinuz-${kernel}" ]] &&
  pass "running kernel is also the boot-loader default" ||
  warn "running and default kernels differ; reboot before hibernating"

if btrfs device stats -c /; then
  pass "Btrfs device error counters are zero"
else
  fail "Btrfs reports device errors"
fi

if systemctl --failed --quiet; then
  pass "no systemd units are failed"
else
  warn "one or more systemd units are failed"
  systemctl --failed --no-pager
fi

df -h / /boot /boot/efi
echo
echo "Result: ${failures} failure(s), ${warnings} warning(s)"
echo "No suspend, hibernation, reboot, or configuration change was performed."

((failures == 0))
