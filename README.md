<div align="center">

<img src="assets/demo.gif" alt="Shell switching demo" width="100%">

<br>

# hypr-shell-switcher

[![Hyprland](https://img.shields.io/badge/Hyprland-00AABB?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](#)
[![rofi](https://img.shields.io/badge/rofi-FF5555?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/davatorium/rofi)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

</div>

Switches between two Quickshell setups I run — [end-4](https://github.com/end-4/dots-hyprland) and [caelestia](https://github.com/caelestia-dots/shell) — without restarting Hyprland. Uses a frozen-frame overlay so the new shell loads hidden behind it. Has a rofi menu that picks up the shell's Material You colors, shows status and lets you switch, restart or stop.

Other Quickshell shells can be plugged in too, see [Adding a new shell](#adding-a-new-shell).

<div align="center">
<img src="assets/preview.png" alt="Shell switcher menu" width="560">
</div>

## Requirements

| Package | Purpose |
|---|---|
| `quickshell` | the shells |
| `hyprland` | compositor (≥ 0.41) |
| `rofi` (wayland) | menu |
| `grim` | freeze frame |
| `ags` (≥ 3) | transition overlay |
| `python3` | color extraction |
| `app2unit` | systemd launch (optional) |
| `papirus-icon-theme` | menu icons |

## Installation

```sh
git clone https://github.com/kellyson71/hypr-shell-switcher
cd hypr-shell-switcher
./install.sh
```

Then add to your keybinds:

```ini
bind = Super+Control, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh toggle
bind = Super+Control+Shift, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh menu
```

## Usage

| Shortcut | Action |
|---|---|
| `Super+Control+Tab` | switch to next shell |
| `Super+Control+Shift+Tab` | open menu |

```sh
switch-shell.sh toggle
switch-shell.sh caelestia
switch-shell.sh end4
switch-shell.sh menu
```

## How it works

```
~/.config/hypr/
├── active-profile.conf        # overwritten on each switch
├── caelestia-overrides.conf
├── assets/
│   └── illogical-impulse.svg
├── profiles/
│   ├── end4.conf
│   └── caelestia.conf
└── scripts/
    ├── switch-shell.sh
    ├── transition.ts
    └── shell-colors.py
```

Each profile sets `$qsConfig` (which Quickshell folder to load). On switch: waits for rofi to close, takes a screenshot with `grim`, puts it on the Wayland OVERLAY layer via `ags`, reloads Hyprland with the new profile, restarts `qs`, then fades out when the shell answers IPC.

Per-shell keybind overrides are loaded conditionally:

```ini
source = active-profile.conf

# hyprlang if isCaelestia
source = caelestia-overrides.conf
# hyprlang endif
```

## Adding a new shell

Add a profile at `hypr/profiles/<name>.conf`, register it in `shell_list()`, `shell_label()`, `shell_icon()` and `shell_desc()` inside `switch-shell.sh`, and optionally drop an SVG in `hypr/assets/` and a keybind override file alongside.

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
- [Quickshell](https://quickshell.outfoxxed.me) by [outfoxxed](https://git.outfoxxed.me)

## License

[MIT](LICENSE)
