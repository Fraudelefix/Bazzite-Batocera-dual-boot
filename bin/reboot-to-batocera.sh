#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/Desktop/RebootToBatocera"
LOG_FILE="${BASE_DIR}/reboot-to-batocera.log"

USB_LABEL="${1:-BATOCERA}"
NO_REBOOT_ARG="${2:-}"

EFIBOOTMGR="/usr/sbin/efibootmgr"
[[ -x "${EFIBOOTMGR}" ]] || EFIBOOTMGR="/usr/bin/efibootmgr"
SYSTEMCTL="/usr/bin/systemctl"
LSBLK="/usr/bin/lsblk"
BLKID="/usr/sbin/blkid"
[[ -x "${BLKID}" ]] || BLKID="/usr/bin/blkid"
AWK="/usr/bin/awk"
BASENAME="/usr/bin/basename"
CAT="/usr/bin/cat"
GREP="/usr/bin/grep"
SUDO="/usr/bin/sudo"
TAIL="/usr/bin/tail"
TEE="/usr/bin/tee"
DATE="/usr/bin/date"

mkdir -p "${BASE_DIR}"

log() {
  echo "[$("${DATE}" -Is)] $*" | "${TEE}" -a "${LOG_FILE}"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_binaries() {
  local bin
  for bin in \
    "${EFIBOOTMGR}" \
    "${SYSTEMCTL}" \
    "${LSBLK}" \
    "${BLKID}" \
    "${AWK}" \
    "${BASENAME}" \
    "${CAT}" \
    "${GREP}" \
    "${SUDO}" \
    "${TAIL}"
  do
    [[ -x "${bin}" ]] || fail "Missing ${bin}"
  done
}

check_sudo_access() {
  if ! "${SUDO}" -n "${EFIBOOTMGR}" -v >/dev/null 2>&1; then
    fail "sudo NOPASSWD not granted for ${EFIBOOTMGR}"
  fi

  if ! "${SUDO}" -n "${SYSTEMCTL}" --version >/dev/null 2>&1; then
    fail "sudo NOPASSWD not granted for ${SYSTEMCTL}"
  fi
}

normalize_disk_path() {
  local disk_path="$1"

  if [[ "${disk_path}" == /dev/* ]]; then
    printf '%s\n' "${disk_path}"
    return
  fi

  printf '/dev/%s\n' "${disk_path}"
}

find_batocera_partition() {
  local match

  match="$("${LSBLK}" -prno PATH,LABEL,FSTYPE,PKNAME,TYPE | "${AWK}" -v label="${USB_LABEL}" '$5=="part" && $2==label && $3=="vfat"{print $1" "$4; exit}')"
  if [[ -z "${match}" ]]; then
    match="$("${LSBLK}" -prno PATH,LABEL,FSTYPE,PKNAME,TYPE | "${AWK}" -v label="${USB_LABEL}" '$5=="part" && $2==label{print $1" "$4; exit}')"
  fi

  [[ -n "${match}" ]] || fail "No partition found with label '${USB_LABEL}'"
  printf '%s\n' "${match}"
}

find_existing_boot_id() {
  local partuuid="$1"

  "${SUDO}" -n "${EFIBOOTMGR}" -v | "${AWK}" -v partuuid="${partuuid}" '
    /^Boot[0-9A-F]{4}\*/ {
      line=$0
      id=substr($1, 5)
      if (partuuid != "" && index(line, partuuid)) {
        print id
        exit
      }
      if (index(tolower(line), "\\efi\\batocera\\shimx64.efi")) {
        print id
        exit
      }
    }
  '
}

create_boot_entry() {
  local parent_disk="$1"
  local part_num="$2"

  log "No existing UEFI entry for this USB; creating..."

  if ! "${SUDO}" -n "${EFIBOOTMGR}" -c -d "${parent_disk}" -p "${part_num}" -L "Batocera (USB)" -l "\\\\EFI\\\\batocera\\\\shimx64.efi"; then
    log "WARN: shim path failed; trying generic \\EFI\\BOOT\\BOOTX64.EFI"
    "${SUDO}" -n "${EFIBOOTMGR}" -c -d "${parent_disk}" -p "${part_num}" -L "Batocera (USB)" -l "\\\\EFI\\\\BOOT\\\\BOOTX64.EFI" || true
  fi
}

main() {
  local match
  local efi_part
  local parent_disk_raw
  local parent_disk
  local block_name
  local part_num
  local partuuid
  local boot_id

  log "=== Reboot to Batocera ==="
  log "USB_LABEL='${USB_LABEL}'"

  require_binaries
  check_sudo_access

  log "lsblk snapshot:"
  "${LSBLK}" -o NAME,LABEL,FSTYPE,SIZE,PATH,TYPE | "${TEE}" -a "${LOG_FILE}"

  match="$(find_batocera_partition)"
  read -r efi_part parent_disk_raw <<< "${match}"
  parent_disk="$(normalize_disk_path "${parent_disk_raw}")"

  block_name="$("${BASENAME}" "${efi_part}")"
  part_num="$("${CAT}" "/sys/class/block/${block_name}/partition")"
  [[ -n "${part_num}" ]] || fail "Could not determine partition number for ${efi_part}"

  partuuid="$("${BLKID}" -s PARTUUID -o value "${efi_part}" 2>/dev/null || true)"
  log "Matched partition: ${efi_part} | parent: ${parent_disk} | part#: ${part_num} | PARTUUID: ${partuuid:-unknown}"

  boot_id="$(find_existing_boot_id "${partuuid}")"
  boot_id="${boot_id%\*}"

  if [[ -z "${boot_id}" ]]; then
    create_boot_entry "${parent_disk}" "${part_num}"
    boot_id="$("${SUDO}" -n "${EFIBOOTMGR}" -v | "${AWK}" -v partuuid="${partuuid}" '
      /^Boot[0-9A-F]{4}\*/ {
        if (partuuid != "" && index($0, partuuid)) {
          print substr($1, 5)
        } else if (index(tolower($0), "\\efi\\batocera\\shimx64.efi") || index(tolower($0), "\\efi\\boot\\bootx64.efi")) {
          print substr($1, 5)
        }
      }
    ' | "${TAIL}" -n 1)"
    boot_id="${boot_id%\*}"
  fi

  [[ -n "${boot_id}" ]] || fail "Could not determine Boot#### for Batocera"

  log "Setting BootNext to: ${boot_id}"
  "${SUDO}" -n "${EFIBOOTMGR}" -n "${boot_id}" >/dev/null 2>&1 || fail "efibootmgr -n failed"
  log "$("${SUDO}" -n "${EFIBOOTMGR}" | "${GREP}" -E '^BootNext:' || true)"

  if [[ "${NO_REBOOT_ARG}" == "noreboot" || "${NO_REBOOT_ARG}" == "--no-reboot" ]]; then
    log "NO-REBOOT mode: BootNext set, not rebooting."
    exit 0
  fi

  log "Rebooting now into Batocera..."
  "${SUDO}" -n "${SYSTEMCTL}" reboot
}

main "$@"
