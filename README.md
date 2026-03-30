# Reboot to Batocera from SteamOS / Bazzite

This project reboots a SteamOS or Bazzite machine directly into a Batocera USB install without using the BIOS boot menu. It is aimed at living-room setups where switching systems should be possible from desktop mode or Steam Big Picture with controller-friendly flows.

## Features

- Detects the Batocera drive by partition label.
- Reuses or creates the correct UEFI boot entry.
- Sets `BootNext` automatically.
- Supports `noreboot` and `--no-reboot` for safe testing.
- Installs a desktop launcher that can be added to Steam as a non-Steam game.

## Repository layout

```text
bin/
  install.sh
  reboot-to-batocera.sh
  uninstall.sh
```

## Quick start

Clone the repository on your Bazzite or SteamOS machine, then run:

```bash
chmod +x bin/*.sh
./bin/install.sh
```

If your Batocera EFI partition is not labeled `BATOCERA`, pass the label explicitly:

```bash
./bin/install.sh MY_BATOCERA_LABEL
```

The installer will:

- Copy the reboot script to `~/Desktop/RebootToBatocera/reboot-to-batocera.sh`
- Create `/etc/sudoers.d/99-reboot-batocera`
- Create `~/.local/share/applications/reboot-to-batocera.desktop`

## Usage

Test without rebooting:

```bash
"$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh" BATOCERA noreboot
tail -n 80 "$HOME/Desktop/RebootToBatocera/reboot-to-batocera.log"
```

Real reboot:

```bash
"$HOME/Desktop/RebootToBatocera/reboot-to-batocera.sh" BATOCERA
```

If you installed with a custom label, use that label in both commands.

## Add to Steam

The installer creates `~/.local/share/applications/reboot-to-batocera.desktop`. In Steam, add that launcher as a non-Steam game. It will then show up in desktop mode and Big Picture.

## Uninstall

```bash
chmod +x bin/uninstall.sh
./bin/uninstall.sh
```

## Notes

- The installer uses the current Linux username for the sudoers rule instead of assuming a fixed `bazzite` user.
- Shell scripts are tracked with LF line endings via `.gitattributes` so the files stay Linux-safe even when edited from Windows.
