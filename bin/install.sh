#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/Desktop/RebootToBatocera}"
SCRIPT_SOURCE="${REPO_DIR}/bin/reboot-to-batocera.sh"
SCRIPT_DEST="${INSTALL_DIR}/reboot-to-batocera.sh"
DESKTOP_FILE="${HOME}/.local/share/applications/reboot-to-batocera.desktop"
SUDOERS_FILE="/etc/sudoers.d/99-reboot-batocera"
USB_LABEL="${1:-BATOCERA}"
USERNAME="${SUDOERS_USER:-$(id -un)}"

[[ -f "${SCRIPT_SOURCE}" ]] || {
  echo "ERROR: Could not find ${SCRIPT_SOURCE}" >&2
  exit 1
}

mkdir -p "${INSTALL_DIR}" "$(dirname "${DESKTOP_FILE}")"
cp "${SCRIPT_SOURCE}" "${SCRIPT_DEST}"
chmod 755 "${SCRIPT_DEST}"

cat <<EOF | sudo tee "${SUDOERS_FILE}" >/dev/null
${USERNAME} ALL=(root) NOPASSWD: /usr/sbin/efibootmgr, /usr/bin/efibootmgr, /usr/bin/systemctl
EOF
sudo chmod 440 "${SUDOERS_FILE}"

printf -v launcher_command '/usr/bin/bash %q %q' "${SCRIPT_DEST}" "${USB_LABEL}"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Reboot to Batocera
Exec=/usr/bin/flatpak-spawn --host /usr/bin/bash -lc "${launcher_command}"
Terminal=false
Categories=Game;
EOF

cat <<EOF
Installed:
- Script: ${SCRIPT_DEST}
- Desktop launcher: ${DESKTOP_FILE}
- Sudoers rule: ${SUDOERS_FILE}

Test without rebooting:
"${SCRIPT_DEST}" "${USB_LABEL}" noreboot
tail -n 80 "${INSTALL_DIR}/reboot-to-batocera.log"
EOF
