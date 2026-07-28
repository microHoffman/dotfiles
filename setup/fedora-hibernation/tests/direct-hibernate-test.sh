#!/usr/bin/env bash
set -euo pipefail

state_root="${HIBERNATE_TEST_STATE_DIR:-/var/lib/hibernate-validation}"
action="${1:-}"
test_number="${2:-}"
confirmation="${3:-}"

usage() {
  cat <<'EOF'
Usage:
  direct-hibernate-test.sh prepare TEST_NUMBER
  direct-hibernate-test.sh hibernate TEST_NUMBER --i-saved-my-work
  direct-hibernate-test.sh check TEST_NUMBER
  direct-hibernate-test.sh cleanup TEST_NUMBER

prepare records the boot, session, process, swap, and journal baseline and starts
a sentinel service. hibernate is the only action that changes power state and
requires the literal --i-saved-my-work guard. check compares state after resume.
cleanup removes the sentinel after an accepted or abandoned test.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ "${action}" == "-h" ]] || [[ "${action}" == "--help" ]]; then
  usage
  exit 0
fi

[[ "${EUID}" -eq 0 ]] || die "run this tool with sudo"
[[ "${test_number}" =~ ^[1-9][0-9]*$ ]] || {
  usage >&2
  exit 2
}

test_dir="${state_root}/test-${test_number}"
unit="hibernate-validation-test-${test_number}.service"

can_hibernate() {
  [[ "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager CanHibernate)" == 's "yes"' ]]
}

check_swap() {
  swapon --show=NAME --noheadings | grep -qx '/dev/zram0' ||
    die "zram is not active"
  swapon --show=NAME --noheadings | grep -qx '/var/swap/swapfile' ||
    die "disk-backed swap is not active"
  btrfs inspect-internal map-swapfile -r /var/swap/swapfile |
    grep -Eq '^[0-9]+$' || die "Btrfs resume offset is invalid"
}

case "${action}" in
  prepare)
    [[ ! -e "${test_dir}" ]] || die "${test_dir} already exists"
    can_hibernate || die "systemd does not report CanHibernate=yes"
    check_swap
    grep -qw disk /sys/power/state || die "kernel disk state is unavailable"

    install -d -m 0750 "${state_root}" "${test_dir}"
    journalctl --sync
    systemd-run --quiet --unit="${unit}" --property=Type=exec \
      --description="Hibernation validation sentinel ${test_number}" \
      /usr/bin/sleep infinity

    sentinel_pid="$(systemctl show -p MainPID --value "${unit}")"
    [[ "${sentinel_pid}" =~ ^[1-9][0-9]*$ ]] ||
      die "failed to start sentinel"

    cat /proc/sys/kernel/random/boot_id >"${test_dir}/boot-id.before"
    date '+%Y-%m-%d %H:%M:%S' >"${test_dir}/wall-clock.before"
    cat /proc/uptime >"${test_dir}/uptime.before"
    uname -a >"${test_dir}/uname.before"
    printf '%s\n' "${unit}" >"${test_dir}/sentinel-unit"
    printf '%s\n' "${sentinel_pid}" >"${test_dir}/sentinel-pid.before"
    cat "/proc/${sentinel_pid}/stat" >"${test_dir}/sentinel-stat.before"
    swapon --show=NAME,TYPE,SIZE,USED,PRIO,UUID,LABEL \
      >"${test_dir}/swapon.before"
    loginctl list-sessions --no-legend >"${test_dir}/sessions.before"
    ps -eo user,pid,ppid,lstart,stat,comm,args >"${test_dir}/processes.before"
    systemd-inhibit --list >"${test_dir}/inhibitors.before"
    journalctl -b -n 0 --show-cursor --no-pager |
      sed -n 's/^-- cursor: //p' >"${test_dir}/journal-cursor.before"
    [[ -s "${test_dir}/journal-cursor.before" ]] ||
      die "failed to record journal cursor"

    echo "Prepared test ${test_number}."
    echo "Boot ID: $(<"${test_dir}/boot-id.before")"
    echo "Sentinel PID: ${sentinel_pid}"
    echo "No hibernation was triggered."
    ;;

  hibernate)
    [[ "${confirmation}" == "--i-saved-my-work" ]] ||
      die "save work, then pass --i-saved-my-work"
    [[ -d "${test_dir}" ]] || die "prepare the test first"
    systemctl is-active --quiet "${unit}" || die "sentinel is not active"
    [[ "$(cat /proc/sys/kernel/random/boot_id)" == \
      "$(<"${test_dir}/boot-id.before")" ]] ||
      die "boot ID changed after preparation"
    can_hibernate || die "systemd does not report CanHibernate=yes"
    check_swap

    date '+%Y-%m-%d %H:%M:%S' >"${test_dir}/hibernate-command.before"
    journalctl --sync
    sync
    echo "Starting direct hibernation test ${test_number}."
    echo "After power-off, press power once and enter the LUKS passphrase."
    systemctl hibernate
    date '+%Y-%m-%d %H:%M:%S' >"${test_dir}/hibernate-command.returned"
    echo "The command returned; run the check action."
    ;;

  check)
    [[ -d "${test_dir}" ]] || die "test state does not exist"
    old_boot_id="$(<"${test_dir}/boot-id.before")"
    old_pid="$(<"${test_dir}/sentinel-pid.before")"
    current_boot_id="$(cat /proc/sys/kernel/random/boot_id)"
    cursor="$(<"${test_dir}/journal-cursor.before")"
    result="PASS"

    journalctl --sync
    date '+%Y-%m-%d %H:%M:%S' >"${test_dir}/wall-clock.after"
    printf '%s\n' "${current_boot_id}" >"${test_dir}/boot-id.after"
    swapon --show=NAME,TYPE,SIZE,USED,PRIO,UUID,LABEL \
      >"${test_dir}/swapon.after"
    loginctl list-sessions --no-legend >"${test_dir}/sessions.after"
    ps -eo user,pid,ppid,lstart,stat,comm,args >"${test_dir}/processes.after"
    journalctl --after-cursor="${cursor}" --no-pager \
      >"${test_dir}/journal-hibernate-resume.txt"
    grep -Ei 'hibernate|hibernation|resume|PM:|swsusp|image' \
      "${test_dir}/journal-hibernate-resume.txt" \
      >"${test_dir}/journal-hibernate-resume.filtered.txt" || true
    journalctl --quiet --after-cursor="${cursor}" -p err --no-pager \
      >"${test_dir}/journal-errors.txt"

    if [[ "${current_boot_id}" != "${old_boot_id}" ]]; then
      echo "FAIL: boot ID changed; the old kernel session was not restored."
      result="FAIL"
    fi

    if ! systemctl is-active --quiet "${unit}"; then
      echo "FAIL: sentinel unit is inactive."
      result="FAIL"
    fi

    current_pid="$(systemctl show -p MainPID --value "${unit}" 2>/dev/null ||
      true)"
    printf '%s\n' "${current_pid}" >"${test_dir}/sentinel-pid.after"
    if [[ "${current_pid}" != "${old_pid}" ]] ||
      [[ ! -r "/proc/${old_pid}/stat" ]]; then
      echo "FAIL: sentinel PID was not preserved."
      result="FAIL"
    fi

    if ! can_hibernate; then
      echo "FAIL: systemd no longer reports CanHibernate=yes."
      result="FAIL"
    fi

    if ! swapon --show=NAME --noheadings | grep -qx '/dev/zram0' ||
      ! swapon --show=NAME --noheadings |
        grep -qx '/var/swap/swapfile'; then
      echo "FAIL: expected swap devices are not both active."
      result="FAIL"
    fi

    if [[ "${result}" == "PASS" ]] && [[ -s "${test_dir}/journal-errors.txt" ]]; then
      echo "WARN: the session restored, but error-priority journal entries need review."
      result="WARN"
    fi

    printf '%s\n' "${result}" >"${test_dir}/RESULT"
    echo "Automated result: ${result}"
    echo "Boot ID before: ${old_boot_id}"
    echo "Boot ID after:  ${current_boot_id}"
    echo "Sentinel PID before: ${old_pid}"
    echo "Sentinel PID after:  ${current_pid}"
    echo
    echo "Hibernate/resume journal evidence:"
    cat "${test_dir}/journal-hibernate-resume.filtered.txt"
    echo
    echo "Errors since preparation:"
    cat "${test_dir}/journal-errors.txt"
    echo
    echo "Manually confirm windows, terminals, editors, and test text."
    ;;

  cleanup)
    systemctl stop "${unit}" 2>/dev/null || true
    systemctl reset-failed "${unit}" 2>/dev/null || true
    echo "Stopped sentinel ${unit}."
    echo "Test evidence remains in ${test_dir}."
    ;;

  *)
    usage >&2
    exit 2
    ;;
esac
