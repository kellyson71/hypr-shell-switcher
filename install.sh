#!/usr/bin/env bash
# Instala o hypr-shell-switcher em ~/.config/hypr.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hypr"
DEST="$HOME/.config/hypr"
HYPRCONF="$DEST/hyprland.conf"

echo ":: Copiando arquivos para $DEST"
mkdir -p "$DEST/scripts" "$DEST/profiles"
cp "$SRC/scripts/switch-shell.sh" "$DEST/scripts/"
cp "$SRC/scripts/shell-colors.py" "$DEST/scripts/"
cp "$SRC/caelestia-overrides.conf" "$DEST/"
cp "$SRC/profiles/end4.conf" "$DEST/profiles/"
cp "$SRC/profiles/caelestia.conf" "$DEST/profiles/"
chmod +x "$DEST/scripts/switch-shell.sh" "$DEST/scripts/shell-colors.py"

if [[ ! -f "$DEST/active-profile.conf" ]]; then
    echo ":: Criando active-profile.conf (padrão: end4)"
    cp "$DEST/profiles/end4.conf" "$DEST/active-profile.conf"
fi

if ! grep -q "active-profile.conf" "$HYPRCONF" 2>/dev/null; then
    echo ":: Registrando os sources no hyprland.conf"
    {
        echo ""
        echo "source = active-profile.conf"
        echo "# hyprlang if isCaelestia"
        echo "source = caelestia-overrides.conf"
        echo "# hyprlang endif"
    } >> "$HYPRCONF"
fi

echo ":: Pronto. Adicione os atalhos ao seu keybinds.conf:"
echo "   bind = Super+Control, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh toggle"
echo "   bind = Super+Control+Shift, Tab, exec, ~/.config/hypr/scripts/switch-shell.sh menu"
