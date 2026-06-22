#!/usr/bin/env bash
# Alterna entre shells Quickshell (end-4 / caelestia / ...) no Hyprland.
#
#   switch-shell.sh                -> toggle para o próximo shell
#   switch-shell.sh toggle         -> idem
#   switch-shell.sh menu           -> menu rofi (trocar / reiniciar / config / reload)
#   switch-shell.sh end4|caelestia -> troca direto para o shell indicado
#   switch-shell.sh <qsConfig>     -> troca para qualquer shell detectado

PROFILES_DIR="$HOME/.config/hypr/profiles"
ACTIVE="$HOME/.config/hypr/active-profile.conf"
QS_DIR="$HOME/.config/quickshell"
SCRIPT_DIR="$HOME/.config/hypr/scripts"
TRANSITION_IMG="/tmp/shell-transition.png"
BEZIER=".4,0,.2,1"
FPS=120

current_qs() { grep -oP '(?<=qsConfig = )\w+' "$ACTIVE" 2>/dev/null; }
notify() { notify-send -a "Shell" -t 2500 "$1" "${2:-}" 2>/dev/null; }

qs_to_profile() { case "$1" in ii) echo end4 ;; *) echo "$1" ;; esac; }
profile_to_qs() { case "$1" in end4) echo ii ;; *) echo "$1" ;; esac; }

shell_label() { case "$1" in ii) echo "end-4" ;; caelestia) echo "caelestia" ;; *) echo "$1" ;; esac; }
shell_desc()  { case "$1" in ii) echo "illogical-impulse" ;; caelestia) echo "caelestia-shell" ;; *) echo "Quickshell" ;; esac; }

shell_icon() {
    case "$1" in
        caelestia) echo "$QS_DIR/caelestia/assets/logo.svg" ;;
        ii)        echo "/usr/share/icons/cachyos.svg" ;;
        *)         echo "preferences-desktop-display" ;;
    esac
}

shell_version() {
    case "$1" in
        caelestia) pacman -Q caelestia-shell 2>/dev/null | awk '{print "v"$2}' | sed 's/-[0-9]*$//' ;;
        ii)        local h; h=$(git -C "$HOME/dots-hyprland" rev-parse --short HEAD 2>/dev/null); echo "${h:+#$h}" ;;
        *)         echo "" ;;
    esac
}

detect_shells() {
    local d
    for d in "$QS_DIR"/*/shell.qml; do
        [[ -e "$d" ]] || continue
        basename "$(dirname "$d")"
    done
}

# pid do shell real, ignorando os watchers wl-paste que também citam "qs -c X"
shell_pid() {
    local p cmd
    for p in $(pgrep -f "qs -c $1" 2>/dev/null); do
        cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
        case "$cmd" in
            *wl-paste*) ;;
            *"qs -c $1"*) echo "$p"; return ;;
        esac
    done
}

shell_status() {
    local pid secs
    pid=$(shell_pid "$1")
    [[ -z "$pid" ]] && { echo "parado"; return; }
    secs=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z "$secs" ]] && { echo "ativo"; return; }
    if   (( secs < 60 ));    then echo "ativo há ${secs}s"
    elif (( secs < 3600 ));  then echo "ativo há $((secs/60))min"
    elif (( secs < 86400 )); then echo "ativo há $((secs/3600))h"
    else                          echo "ativo há $((secs/86400))d"; fi
}

load_colors() { eval "$(python3 "$SCRIPT_DIR/shell-colors.py" "$(current_qs)" 2>/dev/null)"; }

rofi_theme() {
    cat <<EOF
* {
    bg: ${C_BG}; bg2: ${C_BG2}; fg: ${C_FG}; sub: ${C_SUB};
    accent: ${C_ACCENT}; selbg: ${C_SELBG}; selfg: ${C_SELFG}; outline: ${C_OUTLINE};
    background-color: transparent;
    text-color: @fg;
}
window {
    background-color: @bg;
    border: 2px;
    border-color: @accent;
    border-radius: 20px;
    width: 460px;
    padding: 16px;
}
mainbox { spacing: 14px; children: [ inputbar, listview ]; }
inputbar {
    background-color: @bg2;
    text-color: @fg;
    border-radius: 14px;
    padding: 12px 16px;
    spacing: 10px;
    children: [ prompt, entry ];
}
prompt { text-color: @accent; }
entry { placeholder: "buscar…"; placeholder-color: @sub; text-color: @fg; }
listview { spacing: 8px; lines: 6; columns: 1; scrollbar: false; dynamic: true; }
element {
    background-color: transparent;
    text-color: @fg;
    padding: 12px 14px;
    border-radius: 14px;
    spacing: 16px;
}
element normal normal    { background-color: transparent; text-color: @fg; }
element alternate normal { background-color: transparent; text-color: @fg; }
element selected normal   { background-color: @selbg; text-color: @selfg; }
element-icon { size: 2.1em; background-color: transparent; vertical-align: 0.5; }
element-text { background-color: transparent; text-color: inherit; vertical-align: 0.5; }
EOF
}

# Troca de shell com transição: congela a tela durante o restart do quickshell
do_switch() {
    local target="$1" new_qs prev_wall
    new_qs=$(profile_to_qs "$target")

    if [[ "$(current_qs)" == "$new_qs" ]]; then
        notify "Já está em $(shell_label "$new_qs")" "Nenhuma troca necessária."
        return
    fi

    prev_wall=$(swww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -1)
    if command -v grim >/dev/null && command -v swww >/dev/null; then
        grim "$TRANSITION_IMG" 2>/dev/null &&
            swww img "$TRANSITION_IMG" --transition-type fade --transition-bezier "$BEZIER" \
                --transition-duration 0.3 --transition-fps "$FPS" 2>/dev/null
    fi
    notify "Trocando para $(shell_label "$new_qs")…" "Reiniciando o shell."

    cp "$PROFILES_DIR/$target.conf" "$ACTIVE"
    hyprctl reload >/dev/null 2>&1

    pkill -x qs 2>/dev/null
    for _ in $(seq 1 30); do pgrep -x qs >/dev/null || break; sleep 0.1; done

    if command -v app2unit >/dev/null; then
        app2unit -- qs -c "$new_qs" >/dev/null 2>&1 &
    else
        setsid qs -c "$new_qs" >/dev/null 2>&1 &
    fi

    for _ in $(seq 1 50); do qs -c "$new_qs" ipc show >/dev/null 2>&1 && break; sleep 0.2; done
    sleep 0.4

    [[ -n "$prev_wall" ]] && command -v swww >/dev/null &&
        swww img "$prev_wall" --transition-type grow --transition-pos center \
            --transition-bezier "$BEZIER" --transition-duration 0.6 --transition-fps "$FPS" 2>/dev/null

    notify "$(shell_label "$new_qs") ativo" "Shell trocado com sucesso."
}

do_restart() {
    local qs; qs=$(current_qs)
    notify "Reiniciando $(shell_label "$qs")…"
    pkill -x qs 2>/dev/null; sleep 0.5
    if command -v app2unit >/dev/null; then app2unit -- qs -c "$qs" >/dev/null 2>&1 &
    else setsid qs -c "$qs" >/dev/null 2>&1 & fi
}

do_config() {
    local qs; qs=$(current_qs)
    if [[ -f "$QS_DIR/$qs/settings.qml" ]]; then
        app2unit -- qs -p "$QS_DIR/$qs/settings.qml" >/dev/null 2>&1 &
    else
        case "$qs" in
            caelestia) xdg-open "$HOME/.config/caelestia/shell.json" >/dev/null 2>&1 & ;;
            ii)        xdg-open "$HOME/.config/illogical-impulse/config.json" >/dev/null 2>&1 & ;;
        esac
    fi
}

show_menu() {
    load_colors
    local active theme
    active=$(current_qs)
    theme=$(rofi_theme)

    local -a LABELS ICONS ACTIONS
    local s ver st

    ver=$(shell_version "$active"); st=$(shell_status "$active")
    LABELS+=("<span color='${C_ACCENT}' weight='bold'>$(shell_label "$active")</span>  <span color='${C_ACCENT}' size='small'>● em uso</span>  <span size='small' alpha='65%'>${ver:-—} · ${st}</span>")
    ICONS+=("$(shell_icon "$active")")
    ACTIONS+=("noop")

    while read -r s; do
        [[ -z "$s" || "$s" == "$active" ]] && continue
        ver=$(shell_version "$s"); st=$(shell_status "$s")
        LABELS+=("<b>Trocar para $(shell_label "$s")</b>  <span size='small' alpha='65%'>$(shell_desc "$s") · ${ver:-—} · ${st}</span>")
        ICONS+=("$(shell_icon "$s")")
        ACTIONS+=("switch:$(qs_to_profile "$s")")
    done < <(detect_shells)

    # Ícones de ação por path absoluto: rofi-wayland nem sempre resolve nomes de tema
    LABELS+=("<b>Reiniciar</b>  <span size='small' alpha='65%'>$(shell_label "$active")</span>")
    ICONS+=("/usr/share/icons/Papirus/24x24/actions/view-refresh.svg"); ACTIONS+=("restart")
    LABELS+=("<b>Configuração</b>  <span size='small' alpha='65%'>$(shell_label "$active")</span>")
    ICONS+=("/usr/share/icons/Papirus/64x64/apps/preferences-system.svg"); ACTIONS+=("config")
    LABELS+=("<b>Recarregar Hyprland</b>  <span size='small' alpha='65%'>aplicar binds/regras</span>")
    ICONS+=("/usr/share/icons/Papirus/64x64/apps/system-reboot.svg"); ACTIONS+=("reload")

    # Ícones do rofi exigem o separador NUL (\0icon\x1f<path>). Como o bash
    # descarta NUL ao guardar em variável, geramos as linhas direto no pipe.
    local sel i
    sel=$(
        for i in "${!LABELS[@]}"; do
            printf '%s\0icon\x1f%s\n' "${LABELS[$i]}" "${ICONS[$i]}"
        done | rofi -dmenu -i -show-icons -markup-rows -format i -theme-str "$theme" -p "shell" 2>/dev/null
    )
    [[ -z "$sel" ]] && exit 0

    local action="${ACTIONS[$sel]}"
    case "$action" in
        noop)     : ;;
        switch:*) do_switch "${action#switch:}" ;;
        restart)  do_restart ;;
        config)   do_config ;;
        reload)   hyprctl reload >/dev/null 2>&1 && notify "Hyprland recarregado" ;;
    esac
}

# Próximo shell na lista detectada (round-robin)
toggle_target() {
    local cur; cur=$(current_qs)
    local -a list; mapfile -t list < <(detect_shells)
    local n=${#list[@]} i
    (( n == 0 )) && return
    for i in "${!list[@]}"; do
        if [[ "${list[$i]}" == "$cur" ]]; then
            echo "${list[$(((i + 1) % n))]}"; return
        fi
    done
    echo "${list[0]}"
}

case "${1:-toggle}" in
    menu)            show_menu ;;
    toggle|"")       do_switch "$(qs_to_profile "$(toggle_target)")" ;;
    end4|caelestia)  do_switch "$1" ;;
    *)               do_switch "$(qs_to_profile "$1")" ;;
esac
