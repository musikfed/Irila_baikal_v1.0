# Irina Baikal 1.0 — English Overview

**Project:** PegiNelab OS. Portable Ubuntu-derived operating system for Acer Swift 3 SF314-41, to boot from a separate USB 3.0 M.2 SSD. The Windows 11 Pro internal SSD remains untouched.

**Hardware:** AMD Ryzen 5 3500U (4C/8T), Radeon Vega 8, 20 GB RAM, Qualcomm Atheros QCA61x4A Wi-Fi, Realtek audio, HD WebCam. Drivers are **candidates** until verified on the real Acer: `amdgpu`, `ath10k_pci`, `snd_hda_intel`, `uvcvideo`.

**User experience:** Irina Shell uses a lake-blue/taiga-green palette, pop-up launcher, local AI integration, personal Irina Browser (Qt WebEngine), detachable round selfie widget with camera OFF by default, and video calls using external Jitsi Meet.

**Languages:** Shell interface in Russian and English, selectable with the RU/EN button. Keyboard layout is a separate operating-system setting: Windows Win+Space; Ubuntu XFCE/X11 Alt+Shift (after XKB setup); Wayland depends on compositor.

**Free applications:** LibreOffice (Writer, Calc, Impress, Draw, Base, Math), GIMP, Inkscape, Thunderbird multi-account email, Linphone SIP client, and Aisleriot/GNOME Mines/GNOME Mahjongg mini-games. Applications are launched only on Linux if separately installed. Asterisk is an optional, separately configured PBX server, not included by default.

**Data protection:** The final disk image needs a writable persistent data partition, preferably LUKS2-encrypted, for home directories, mailbox profiles, SIP credentials, documents and browser settings. A RAM-only overlay would erase all such data on shutdown.

**Current status:** Shell UI v0.5 prototype and installation instructions are committed to GitHub. The fully bootable, signed and Acer-tested `irina_baikal_1.0.img` has **not** been produced. The Windows preview can demonstrate menus and preferences, but cannot launch Ubuntu desktop packages.

More: [Russian and English apps/locales instructions](LOCALIZATION_AND_APPS.md).
