#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-${HOME}/Desktop/RebootToBatocera}"
DESKTOP_FILE="${HOME}/.local/share/applications/reboot-to-batocera.desktop"
SUDOERS_FILE="/etc/sudoers.d/99-reboot-batocera"

rm -rf "${INSTALL_DIR}"
rm -f "${DESKTOP_FILE}"
sudo rm -f "${SUDOERS_FILE}"

cat <<EOF
Removed:
- ${INSTALL_DIR}
- ${DESKTOP_FILE}
- ${SUDOERS_FILE}
EOF
