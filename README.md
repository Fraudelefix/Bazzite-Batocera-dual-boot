# Reboot to Batocera from SteamOS / Bazzite

This utility allows you to reboot your Steam Deck (or any Linux PC) directly into a Batocera USB drive without needing to go through the BIOS boot menu.
I initially had 2 different PC under the TV, one running Bazzite and one running Batocera, to avoid having to go to the BIOS boot menu and chosing which OS to boot to.
My goal with was to use a single PC running both (i) a SteamOS PC and (ii) Batocera, with the ability to switch between the two only with controller inputs.
I have zero coding knowledge, this was built entirely by ChatGPT-5 (after a lot of trial and error). I have no idea if there is a better way to do it. This just works for me.

### Features
- Detects Batocera USB by label.
- Sets EFI BootNext automatically.
- Optional "no reboot" mode for testing.
- Works from desktop or Steam Big Picture Mode.

---

# Installation process

### 3) Create the script

```bash
nano "$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh"
```

Paste this script :

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$HOME/Desktop/RebootToBatocera"
LOG_FILE="$BASE_DIR/reboot-to-batocera.log"

USB_LABEL="${1:-BATOCERA}"     # pass a different label if your stick isn't named BATOCERA
NO_REBOOT_ARG="${2:-}"         # add "noreboot" to test without restarting

# Absolute binaries with simple fallbacks for portability
EFIBOOTMGR="/usr/sbin/efibootmgr";  [[ -x "$EFIBOOTMGR" ]] || EFIBOOTMGR="/usr/bin/efibootmgr"
SYSTEMCTL="/usr/bin/systemctl"
LSBLK="/usr/bin/lsblk"
BLKID="/usr/sbin/blkid";           [[ -x "$BLKID" ]] || BLKID="/usr/bin/blkid"
AWK="/usr/bin/awk"
BASENAME="/usr/bin/basename"
CAT="/usr/bin/cat"
SUDO="/usr/bin/sudo"
TEE="/usr/bin/tee"
DATE="/usr/bin/date"
GREP="/usr/bin/grep"
TAIL="/usr/bin/tail"
SLEEP="/usr/bin/sleep"

mkdir -p "$BASE_DIR"
log(){ echo "[$("$DATE" -Is)] $*" | "$TEE" -a "$LOG_FILE"; }

log "=== Reboot to Batocera (v6) ==="
log "USB_LABEL='$USB_LABEL'"

# Ensure required binaries exist
for bin in "$EFIBOOTMGR" "$SYSTEMCTL" "$LSBLK" "$BLKID" "$AWK" "$BASENAME" "$CAT" "$SUDO"; do
  [[ -x "$bin" ]] || { log "ERROR: Missing $bin"; exit 1; }
done

# Steam-safe NOPASSWD checks (check the real commands, not 'sudo true')
if ! $SUDO -n "$EFIBOOTMGR" -v >/dev/null 2>&1; then
  log "ERROR: sudo NOPASSWD not granted for $EFIBOOTMGR"; exit 1;
fi
if ! $SUDO -n "$SYSTEMCTL" --version >/dev/null 2>&1; then
  log "ERROR: sudo NOPASSWD not granted for $SYSTEMCTL"; exit 1;
fi

log "lsblk snapshot:"
$LSBLK -o NAME,LABEL,FSTYPE,SIZE,PATH,TYPE | "$TEE" -a "$LOG_FILE"

# Find the partition with the label (prefer the vfat EFI partition)
match="$($LSBLK -prno PATH,LABEL,FSTYPE,PKNAME,TYPE | $AWK -v L="$USB_LABEL" '$5=="part" && $2==L && $3=="vfat"{print $1" "$4; exit}')"
if [[ -z "$match" ]]; then
  match="$($LSBLK -prno PATH,LABEL,FSTYPE,PKNAME,TYPE | $AWK -v L="$USB_LABEL" '$5=="part" && $2==L{print $1" "$4; exit}')"
fi
[[ -n "$match" ]] || { log "ERROR: No partition found with label '$USB_LABEL'"; exit 1; }

efi_part=$(echo "$match" | awk '{print $1}')
pkname=$(echo "$match"   | awk '{print $2}')
parent_disk="$pkname"
bn="$($BASENAME "$efi_part")"
part_num="$($CAT /sys/class/block/$bn/partition)"
PARTUUID="$($BLKID -s PARTUUID -o value "$efi_part" 2>/dev/null || true)"
log "Matched partition: $efi_part | parent: $parent_disk | part#: $part_num | PARTUUID: ${PARTUUID:-unknown}"

# Reuse an existing UEFI entry (match PARTUUID or Batocera shim path)
boot_id="$($EFIBOOTMGR -v | $AWK -v P="$PARTUUID" '/^Boot[0-9A-F]{4}\*/{line=$0; id=substr($1,5);
  if (P!="" && index(line,P)) {print id; exit}
  if (index(tolower(line),"\\efi\\batocera\\shimx64.efi")) {print id; exit}
}')"
boot_id="${boot_id%\*}"   # strip any trailing *

# Create if missing (try shim path first, then generic BOOTX64)
if [[ -z "$boot_id" ]]; then
  log "No existing UEFI entry for this USB; creating…"
  if ! $SUDO -n "$EFIBOOTMGR" -c -d "$parent_disk" -p "$part_num" -L "Batocera (USB)" -l "\\\\EFI\\\\batocera\\\\shimx64.efi"; then
    log "WARN: shim path failed; trying generic \\EFI\\BOOT\\BOOTX64.EFI"
    $SUDO -n "$EFIBOOTMGR" -c -d "$parent_disk" -p "$part_num" -L "Batocera (USB)" -l "\\\\EFI\\\\BOOT\\\\BOOTX64.EFI" || true
  fi
  boot_id="$($EFIBOOTMGR -v | $AWK -v P="$PARTUUID" '/^Boot[0-9A-F]{4}\*/ && index($0,P){print substr($1,5)}' | $TAIL -n1)"
  boot_id="${boot_id%\*}"
fi

[[ -n "$boot_id" ]] || { log "ERROR: Could not determine Boot#### for Batocera"; exit 1; }

log "Setting BootNext to: $boot_id"
$SUDO -n "$EFIBOOTMGR" -n "$boot_id" >/dev/null 2>&1 || { log "ERROR: efibootmgr -n failed"; exit 1; }
log "$($EFIBOOTMGR | $GREP -E "^BootNext:" || true)"

if [[ "${NO_REBOOT_ARG:-}" == "noreboot" ]]; then
  log "NO-REBOOT mode: BootNext set, not rebooting."
  exit 0
fi

log "Rebooting now into Batocera…"
$SUDO -n "$SYSTEMCTL" reboot
```

Make it executable
```bash
chmod 755 "$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh"
```

### 4) Test from a terminal

Test from a terminal. This should not actually reboot. Instead, you should see entries like:
- Matched partition: /dev/sdX1 …
- Setting BootNext to: 0001
- NO-REBOOT mode: BootNext set, not rebooting.

```bash
"$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh" BATOCERA noreboot
tail -n 80 "$HOME/Desktop/RebootToBatocera/reboot-to-batocera.log"
```

Real reboot:
```bash
"$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh" BATOCERA
```


### 5) Add Steam Big Picture launchers (optional)

```bash
cat > "$HOME/.local/share/applications/reboot-to-batocera.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Reboot to Batocera
Exec=/usr/bin/flatpak-spawn --host /usr/bin/bash -lc "/usr/bin/bash \"$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh\" BATOCERA"
Terminal=false
Categories=Game;
EOF
```
In Steam: Add a Non-Steam Game. Tick "Reboot to Batocera". This will now appear as a game in Steam and BigPicture. Once you run the game, the PC will reboot to Batocera.
