# Reboot to Batocera from SteamOS / Bazzite

This utility allows you to reboot your Steam Deck (or any Linux PC) directly into a Batocera USB drive without needing to go through the BIOS boot menu.
My goal was to use a single PC as (i) a SteamOS PC and (ii) an emulation box and switching between the two only with controller inputs.
I have zero coding knowledge, this was built entirely by ChatGPT-5.

---

## Features
- Detects Batocera USB by label.
- Sets EFI BootNext automatically.
- Optional "no reboot" mode for testing.
- Works from desktop or Steam Big Picture Mode.

---

## Requirements
- Batocera USB stick inserted and labelled `BATOCERA`.
- `efibootmgr` and `systemctl` installed.
- `sudo` configured with NOPASSWD for these commands:
  ```bash
  /usr/sbin/efibootmgr, /usr/bin/systemctl
