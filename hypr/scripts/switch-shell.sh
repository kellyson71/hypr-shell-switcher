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
ASSETS_DIR="$HOME/.config/hypr/assets"
TRANSITION_APP="$SCRIPT_DIR/transition.ts"
FREEZE_IMG="/tmp/shell-transition-freeze.png"
SIGNAL_FILE="/tmp/shell-transition.signal"

current_qs() { grep -oP '(?<=qsConfig = )\w+' "$ACTIVE" 2>/dev/null; }
notify() { notify-send -a "Shell" -t 2500 "$1" "${2:-}" 2>/dev/null; }

qs_to_profile() { case "$1" in ii) echo end4 ;; *) echo "$1" ;; esac; }
profile_to_qs() { case "$1" in end4) echo ii ;; *) echo "$1" ;; esac; }

shell_label() { case "$1" in ii) echo "end-4" ;; caelestia) echo "caelestia" ;; *) echo "$1" ;; esac; }
shell_desc()  { case "$1" in ii) echo "illogical-impulse" ;; caelestia) echo "caelestia-shell" ;; *) echo "Quickshell" ;; esac; }

shell_icon() {
    case "$1" in
        caelestia) echo "$QS_DIR/caelestia/assets/logo.svg" ;;
        ii)        echo "$ASSETS_DIR/illogical-impulse.svg" ;;
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

# Cor de acento (primary) de um shell específico, para o traço lateral do menu
shell_accent() { python3 "$SCRIPT_DIR/shell-colors.py" "$1" primary 2>/dev/null || echo "${C_ACCENT:-#8ab4f8}"; }

# Primeiro path existente da lista; senão devolve o nome de tema (fallback)
action_icon() {
    local fallback="$1"; shift
    local p
    for p in "$@"; do [[ -f "$p" ]] && { printf '%s' "$p"; return; }; done
    printf '%s' "$fallback"
}

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
    width: 500px;
    padding: 16px;
}
mainbox { spacing: 12px; children: [ inputbar, message, listview ]; }
inputbar {
    background-color: @bg2;
    text-color: @fg;
    border-radius: 14px;
    padding: 12px 16px;
    spacing: 10px;
    children: [ prompt, entry ];
}
prompt { text-color: @accent; }
entry { placeholder: "filtrar ou nº…"; placeholder-color: @sub; text-color: @fg; }
message { background-color: @bg2; border-radius: 14px; padding: 10px 16px; }
textbox { text-color: @fg; vertical-align: 0.5; }
listview { spacing: 6px; lines: 8; columns: 1; scrollbar: false; dynamic: true; }
element {
    background-color: transparent;
    text-color: @fg;
    padding: 10px 14px;
    border-radius: 14px;
    spacing: 16px;
}
element normal normal    { background-color: transparent; text-color: @fg; }
element alternate normal { background-color: transparent; text-color: @fg; }
element selected normal   { background-color: @selbg; text-color: @selfg; }
element-icon { size: 2.3em; background-color: transparent; vertical-align: 0.5; }
element-text { background-color: transparent; text-color: inherit; vertical-align: 0.5; }
EOF
}

launch_qs() {
    local qs="$1"
    if command -v app2unit >/dev/null; then
        app2unit -- qs -c "$qs" >/dev/null 2>&1 &
    else
        setsid qs -c "$qs" >/dev/null 2>&1 &
    fi
}

# Sobe o overlay de transição: congela a tela na camada overlay (acima de tudo,
# inclusive do shell novo enquanto carrega) e faz o crossfade da logo num canto.
# Retorna 1 (sem animar) se faltar ags/grim.
start_transition() {
    local from="$1" to="$2" label="$3" _
    command -v ags >/dev/null && command -v grim >/dev/null || return 1
    [[ -f "$TRANSITION_APP" ]] || return 1

    # se a troca veio do menu, espera o rofi sumir das layers antes do print,
    # senão o frame congelado fica com o menu "preso" enquanto ele já fechou
    for _ in $(seq 1 80); do
        hyprctl layers 2>/dev/null | grep -qiE 'namespace:[[:space:]]*rofi' || break
        sleep 0.01
    done

    # desliga a animação de layer (layersIn = popin) do Hyprland só pro overlay:
    # assim o frame congelado aparece instantâneo, sem o "pulo" de entrada.
    # Sintaxe Hyprland >=0.54: match:namespace <ns>, no_anim on
    hyprctl keyword layerrule "match:namespace shell-transition, no_anim on" >/dev/null 2>&1

    grim "$FREEZE_IMG" 2>/dev/null || return 1

    rm -f "$SIGNAL_FILE"
    ags quit -i shelltransition >/dev/null 2>&1
    ST_FREEZE="$FREEZE_IMG" ST_FROM="$from" ST_TO="$to" ST_LABEL="$label" \
        ST_SIGNAL="$SIGNAL_FILE" ST_TIMEOUT=12000 \
        ags run --gtk 4 "$TRANSITION_APP" >/dev/null 2>&1 &

    # espera a surface ser mapeada antes de matar o shell (evita flash)
    local _
    for _ in $(seq 1 30); do
        hyprctl layers 2>/dev/null | grep -q shell-transition && break
        sleep 0.05
    done
}

# Pede o fade-out do overlay (o shell novo já está pronto por baixo)
end_transition() { touch "$SIGNAL_FILE" 2>/dev/null; }

# Troca de shell com transição animada via overlay ags
do_switch() {
    local target="$1" new_qs cur_qs animated=0 _
    new_qs=$(profile_to_qs "$target")
    cur_qs=$(current_qs)

    if [[ "$cur_qs" == "$new_qs" ]]; then
        notify "Já está em $(shell_label "$new_qs")" "Nenhuma troca necessária."
        return
    fi

    start_transition "$(shell_icon "$cur_qs")" "$(shell_icon "$new_qs")" "$(shell_label "$new_qs")" && animated=1

    cp "$PROFILES_DIR/$target.conf" "$ACTIVE"
    hyprctl reload >/dev/null 2>&1

    pkill -x qs 2>/dev/null
    for _ in $(seq 1 30); do pgrep -x qs >/dev/null || break; sleep 0.1; done

    launch_qs "$new_qs"
    for _ in $(seq 1 50); do qs -c "$new_qs" ipc show >/dev/null 2>&1 && break; sleep 0.2; done
    sleep 0.3

    (( animated )) && end_transition
    notify "$(shell_label "$new_qs") ativo" "Shell trocado com sucesso."
}

do_restart() {
    local qs; qs=$(current_qs)
    notify "Reiniciando $(shell_label "$qs")…"
    pkill -x qs 2>/dev/null; sleep 0.5
    launch_qs "$qs"
}

do_stop() {
    local qs; qs=$(current_qs)
    notify "Parando $(shell_label "$qs")…" "Sem shell ativo até reiniciar."
    pkill -x qs 2>/dev/null
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
    local active theme aacc aver ast
    active=$(current_qs)
    theme=$(rofi_theme)

    local -a LABELS ICONS ACTIONS NONSEL
    local NL=$'\n'
    local s ver st acc num=0

    # monta uma linha de duas linhas: traço lateral colorido + nº + título / metadados
    row() { # <accent> <num|""> <título> <sub>
        local bar="<span color='$1'>▌</span>" idx=""
        [[ -n "$2" ]] && idx="  <span alpha='40%' size='small'>$2</span>"
        printf '%s%s  <b>%s</b>%s        <span size="small" alpha="60%%">%s</span>' \
            "$bar" "$idx" "$3" "$NL" "$4"
    }

    # shell ativo (não-selecionável: serve de cabeçalho com a logo)
    aacc=$(shell_accent "$active"); aver=$(shell_version "$active"); ast=$(shell_status "$active")
    LABELS+=("<span color='${aacc}'>▌</span>  <b>$(shell_label "$active")</b>  <span color='${aacc}' size='small'>● em uso</span>${NL}        <span size=\"small\" alpha=\"60%\">${aver:-—} · ${ast}</span>")
    ICONS+=("$(shell_icon "$active")"); ACTIONS+=("noop"); NONSEL+=("true")

    # alvos de troca
    while read -r s; do
        [[ -z "$s" || "$s" == "$active" ]] && continue
        st=$(shell_status "$s"); acc=$(shell_accent "$s")
        num=$((num + 1))
        LABELS+=("$(row "$acc" "$num" "Trocar para $(shell_label "$s")" "$(shell_desc "$s") · ${st}")")
        ICONS+=("$(shell_icon "$s")"); ACTIONS+=("switch:$(qs_to_profile "$s")"); NONSEL+=("false")
    done < <(detect_shells)

    # separador
    LABELS+=("<span alpha='45%' size='small'>AÇÕES</span>")
    ICONS+=(""); ACTIONS+=("noop"); NONSEL+=("true")

    # ações (atuam sobre o shell ativo). Ícones por path com fallback de tema.
    num=$((num + 1)); LABELS+=("$(row "$C_ACCENT" "$num" "Reiniciar" "reinicia $(shell_label "$active")")")
    ICONS+=("$(action_icon view-refresh /usr/share/icons/Papirus/64x64/actions/view-refresh.svg /usr/share/icons/Papirus/24x24/actions/view-refresh.svg)"); ACTIONS+=("restart"); NONSEL+=("false")

    num=$((num + 1)); LABELS+=("$(row "$C_ACCENT" "$num" "Configuração" "abrir config de $(shell_label "$active")")")
    ICONS+=("$(action_icon preferences-system /usr/share/icons/Papirus/64x64/apps/preferences-system.svg /usr/share/icons/Papirus/24x24/apps/preferences-system.svg)"); ACTIONS+=("config"); NONSEL+=("false")

    num=$((num + 1)); LABELS+=("$(row "$C_ACCENT" "$num" "Recarregar Hyprland" "aplicar binds/regras")")
    ICONS+=("$(action_icon system-reboot /usr/share/icons/Papirus/64x64/apps/system-reboot.svg /usr/share/icons/Papirus/24x24/actions/system-reboot.svg)"); ACTIONS+=("reload"); NONSEL+=("false")

    num=$((num + 1)); LABELS+=("$(row "#e06c75" "$num" "Parar shell" "encerra $(shell_label "$active") sem reiniciar")")
    ICONS+=("$(action_icon process-stop /usr/share/icons/Papirus/64x64/actions/process-stop.svg /usr/share/icons/Papirus/24x24/actions/process-stop.svg)"); ACTIONS+=("stop"); NONSEL+=("false")

    # Ícones do rofi exigem o separador NUL (\0icon\x1f<path>). Como o bash
    # descarta NUL ao guardar em variável, geramos as linhas direto no pipe.
    # Usamos RS (\x1e) como separador de entradas (-sep) em vez de \n, para que
    # o \n embutido vire quebra de linha real (linha dupla) dentro do elemento.
    # nonselectable marca o ativo e o separador como não-clicáveis.
    local sel i RS=$'\x1e'
    sel=$(
        for i in "${!LABELS[@]}"; do
            printf '%s\0icon\x1f%s\x1fnonselectable\x1f%s\x1e' "${LABELS[$i]}" "${ICONS[$i]}" "${NONSEL[$i]}"
        done | rofi -dmenu -i -show-icons -markup-rows -format i -sep "$RS" -eh 2 \
            -selected-row 1 \
            -kb-accept-entry "Return,KP_Enter" -kb-remove-to-eol "" \
            -kb-row-down "Down,Control+j" -kb-row-up "Up,Control+k" \
            -theme-str "$theme" -p "trocar" 2>/dev/null
    )
    [[ -z "$sel" ]] && exit 0

    local action="${ACTIONS[$sel]}"
    case "$action" in
        noop)     : ;;
        switch:*) do_switch "${action#switch:}" ;;
        restart)  do_restart ;;
        config)   do_config ;;
        reload)   hyprctl reload >/dev/null 2>&1 && notify "Hyprland recarregado" ;;
        stop)     do_stop ;;
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
