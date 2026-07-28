#!/usr/bin/env bash
set -euo pipefail

swap_file="/var/swap/swapfile"
swap_subvolume="/var/swap"
resume_config="/etc/dracut.conf.d/resume.conf"
lid_config="/etc/systemd/logind.conf.d/50-hibernate-on-lid.conf"
fstab_line='/var/swap/swapfile none swap defaults 0 0'
apply=false

usage() {
  cat <<'EOF'
Usage: rollback.sh [--apply]

Without --apply, prints the rollback plan and changes nothing.
With --apply, backs up configuration, disables and removes the disk-backed
swap file, removes the dracut drop-in, and rebuilds the running initramfs.
It also removes this reference's logind lid-policy drop-in.

This does not shrink partitions, LUKS, or Btrfs and does not downgrade packages.
EOF
}

case "${1:-}" in
  "")
    ;;
  --apply)
    apply=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

cat <<EOF
Fedora hibernation rollback plan:

1. Back up /etc/fstab, ${resume_config}, ${lid_config}, and the running
   initramfs.
2. Disable ${swap_file}; zram is left enabled.
3. Remove only this exact fstab line:
   ${fstab_line}
4. Remove ${resume_config}.
5. Remove ${lid_config} and reload systemd-logind.
6. Rebuild /boot/initramfs-$(uname -r).img.
7. Delete ${swap_file} and the empty ${swap_subvolume} Btrfs subvolume.

The expanded partition, LUKS mapping, and Btrfs filesystem remain expanded.
The systemd update and old-kernel package removal are not reverted.
EOF

if [[ "${apply}" != true ]]; then
  echo
  echo "Dry run only. Rerun with --apply after saving work to perform it."
  exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run rollback with sudo." >&2
  exit 2
fi

read -r -p "Type REMOVE-HIBERNATION to continue: " confirmation
if [[ "${confirmation}" != "REMOVE-HIBERNATION" ]]; then
  echo "Rollback cancelled."
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="/var/backups/fedora-hibernation-rollback-${timestamp}"
mkdir -m 0700 "${backup_dir}"
cp -a /etc/fstab "${backup_dir}/fstab"
[[ -e "${resume_config}" ]] &&
  cp -a "${resume_config}" "${backup_dir}/resume.conf" || true
[[ -e "${lid_config}" ]] &&
  cp -a "${lid_config}" "${backup_dir}/50-hibernate-on-lid.conf" || true
cp -a "/boot/initramfs-$(uname -r).img" "${backup_dir}/"

if swapon --show=NAME --noheadings | grep -qx "${swap_file}"; then
  swapoff "${swap_file}"
fi

fstab_tmp="$(mktemp)"
cleanup() {
  rm -f -- "${fstab_tmp}"
}
trap cleanup EXIT

awk -v target="${fstab_line}" '$0 != target { print }' /etc/fstab >"${fstab_tmp}"
install -o root -g root -m 0644 "${fstab_tmp}" /etc/fstab
rm -f -- "${resume_config}"
rm -f -- "${lid_config}"
systemctl daemon-reload
if systemctl show systemd-logind --property=CanReload --value |
  grep -qx yes; then
  systemctl reload systemd-logind
else
  echo "logind cannot reload; the removed lid policy remains active until reboot." >&2
fi
findmnt --verify --verbose

dracut --force "/boot/initramfs-$(uname -r).img" "$(uname -r)"

if [[ -e "${swap_file}" ]]; then
  rm -f -- "${swap_file}"
fi

if [[ -e "${swap_subvolume}" ]]; then
  if [[ -n "$(find "${swap_subvolume}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "${swap_subvolume} is not empty; refusing to delete it." >&2
    exit 1
  fi
  btrfs subvolume delete "${swap_subvolume}"
fi

trap - EXIT
rm -f -- "${fstab_tmp}"

echo "Rollback completed. Backups: ${backup_dir}"
echo "zram remains enabled. No reboot or hibernation was performed."
