# Irina Baikal 1.0 — RU/EN, office, graphics, phone and mail

**Current version:** Shell v0.5 prototype. Native Linux apps are an integration, NOT standalone applications rewritten by PegiNelab. Bootable IMG has not been built.

## Interface language and keyboard layout are different

* In Irina Shell, top-right **EN / RU** switches interface translation; this affects the shell only and remembers the choice when the browser profile is persistent. Default Russian.
* Windows 11 Pro already provides OS keyboard layouts: **Win + Space** switches the keyboard layout when both have been added in Windows Settings.
* Ubuntu XFCE on **X11/Xorg**: install `x11-xkb-utils` and run `bash scripts/keyboard_x11_ru_en.sh` from a user graphical session. **Alt + Shift** switches between English (US) and Russian layouts. On **Wayland**, configure layouts in the desktop/compositor settings instead; do not rely on setxkbmap.
* For complete OS localization, install `language-pack-ru language-pack-en locales` and configure locale in the Ubuntu build/chroot, NOT on the Windows host. The language button never changes the host OS locale or active keyboard layout.

## Software choices, free/open-source

| Category | Program on Ubuntu 24.04 | Role |
| --- | --- | --- |
| Office | LibreOffice Writer / Calc / Impress / Draw / Base / Math | Documents, spreadsheets, slides, drawings, databases, formulas |
| Photos | GIMP | Photoshop-like raster editor |
| Vector | Inkscape | SVG, vector graphics |
| E-mail | Thunderbird | Universal multiple-account e-mail (IMAP, POP3, SMTP) |
| SIP | Linphone Desktop | SIP audio/video softphone with SIP provider / PBX credentials |
| Small games | Aisleriot, GNOME Mines, GNOME Mahjongg | Solitaire, Minesweeper, Mahjongg |

**Asterisk** is a PBX/server, not required for a personal SIP client. Installing an Asterisk server on a boot-from-USB personal laptop by default is not recommended: it requires administration, network, service security, SIP/TLS configuration, NAT/STUN/TURN and a dedicated phone number/provider for PSTN. Future optional **server** profile can support it; no trunk credentials or SIP passwords belong in GitHub or the OS image.

## Package installation in a Linux build VM (NOT Windows)

Review packages first (safe, no changes):

```bash
bash scripts/install_desktop_apps.sh --full --dry-run
```

Only when working inside the Ubuntu build VM or an explicitly chosen Ubuntu desktop:

```bash
bash scripts/install_desktop_apps.sh --full --install
```

`--core` has smaller package set; `--full` adds GIMP, Inkscape, Linphone, games, Base and Math. Download size and compressed IMG size increase substantially. Do not promise a 3–5 GB all-inclusive image without measuring actual SquashFS and model size.

## Round selfie circle

* Visible by default on the shell desktop but **camera is OFF by default**. No capture until the user presses play and grants permission.
* **×** hides the circle and stops the camera tracks. Re-open it via **Camera** in the menu or **Show / hide camera circle** in quick settings.
* The visibility preference is kept in browser `localStorage` only when the profile is persistent. On a read-only SquashFS with RAM-only OverlayFS, settings reset after restart until a writable `/home` is mounted.

## Native launcher security

The browser shell's `POST /api/launch` accepts **only** a fixed allowlist (`writer`, `calc`, `impress`, `draw`, `base`, `gimp`, `inkscape`, `mail`, `sip`, `solitaire`, `mines`, `mahjongg`). No shell commands or user arguments. It works only on Linux, from an **unprivileged graphical session**, requires JSON and exact same-origin HTTP headers, and refuses launch if a program is missing. When previewed on Windows 11, Irina Shell shows the app menus but will not execute Ubuntu applications.

## Persistent user data on the 256 GB USB SSD

**Critical:** do not store Thunderbird profile/mail, SIP passwords, settings, documents, browser profiles or model downloads in RAM-only overlay. For the image architecture plan:

- GPT ESP FAT32 512 MiB (UEFI);
- read-only system with `filesystem.squashfs`, size according to actual output;
- separate **persistent DATA partition**, preferably LUKS2-encrypted ext4, mounted to persistent `/home` for profile, office documents, mail cache, SIP accounts, and browser settings.

This is a design requirement, **not** a completed and tested installer or disk layout. No disk formatting or UEFI flashing happens when trying the shell UI. Always verify the external 256 GB SSD separately from the internal Windows 512 GB SSD before any write.
