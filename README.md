<div align="center">

# hypr-shell-switcher

Switch between multiple [Quickshell](https://quickshell.outfoxxed.me) shells on [Hyprland](https://hyprland.org) without logging out, with per-shell keybinds, an animated transition and a themed menu.

[![Hyprland](https://img.shields.io/badge/Hyprland-00AABB?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](#)
[![rofi](https://img.shields.io/badge/rofi-FF5555?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/davatorium/rofi)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<img src="assets/menu.png" alt="Shell switcher menu" width="520">

</div>

## About

Runs two (or more) Quickshell shells in the same Hyprland session and switches between them on the fly. Ships ready for the two most popular shells:

- **[end-4](https://github.com/end-4/dots-hyprland)** (`illogical-impulse`) — `~/.config/quickshell/ii`
- **[caelestia](https://github.com/caelestia-dots/shell)** (`caelestia-shell`) — `~/.config/quickshell/caelestia`

Each shell exposes its own globals and shortcuts. This project solves that by loading shell-specific keybinds conditionally, so each one behaves as if it were the only shell installed.

## Features

- **Hot switching** between shells, no session logout
- **Animated transition** — freezes the screen (`grim`) and reveals the new shell with `swww`
- **Themed menu** (`rofi`) that inherits the active shell's Material You colors
- **Per-shell keybinds** — conditional overrides for caelestia (screenshot, launcher, sidebar, session, media, clipboard)
- **Auto-detection** — any folder at `~/.config/quickshell/<name>/shell.qml` shows up in the menu
- **Rich indicators** — version and status (running/stopped, for how long) of each shell
- **Direct toggle** or **full menu** (switch / restart / configure / reload)

## Requirements

| Package | Purpose |
|---|---|
| `quickshell` | the shells themselves |
| `hyprland` | window manager |
| `rofi` (wayland) | selection menu |
| `swww` + `grim` | switch animation |
| `python3` | extracting the theme colors |
| `app2unit` | launch the shell via systemd (optional) |
| `papirus-icon-theme` | icons for the menu actions |

## Installation

```sh
git clone https://github.com/kellyson71/hypr-shell-switcher
cd hypr-shell-switcher
./install.sh
```

The installer copies the files to `~/.config/hypr`, registers the conditional block in `hyprland.conf` and creates the initial `active-profile.conf`. Then add the shortcuts to your `keybinds.conf`:

```ini
bind = Super+Control, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh toggle
bind = Super+Control+Shift, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh menu
```

## Usage

| Shortcut | Action |
|---|---|
| `Super+Control+Tab` | switch directly to the next shell |
| `Super+Control+Shift+Tab` | open the full menu |

Or from the command line:

```sh
switch-shell.sh toggle       # next shell
switch-shell.sh caelestia    # switch directly
switch-shell.sh end4         # switch directly
switch-shell.sh menu         # rofi menu
```

## How it works

```
~/.config/hypr/
├── hyprland.conf              # sources active-profile.conf + conditional block
├── active-profile.conf        # active profile (copy of profiles/<shell>.conf)
├── caelestia-overrides.conf   # caelestia keybinds (loaded when isCaelestia)
├── profiles/
│   ├── end4.conf              # $qsConfig = ii   ; $isCaelestia =
│   └── caelestia.conf         # $qsConfig = caelestia ; $isCaelestia = 1
└── scripts/
    ├── switch-shell.sh        # switching, menu and animation
    └── shell-colors.py        # extracts the active shell's Material You colors
```

Each profile sets the `$qsConfig` variable (which Quickshell folder to load) and the `$isCaelestia` flag. `hyprland.conf` sources `active-profile.conf` at the start and, at the end, loads the caelestia overrides only when the flag is set:

```ini
source = active-profile.conf

# hyprlang if isCaelestia
source = caelestia-overrides.conf
# hyprlang endif
```

Switching shells means: copy the profile to `active-profile.conf`, reload Hyprland and restart `qs` with the new `qsConfig`.

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
- [Quickshell](https://quickshell.outfoxxed.me) by [outfoxxed](https://git.outfoxxed.me)

## License

[MIT](LICENSE)
