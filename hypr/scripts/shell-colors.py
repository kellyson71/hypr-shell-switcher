#!/usr/bin/env python3
"""Extrai cores Material You normalizadas do shell ativo (end-4 ou caelestia).

Uso: shell-colors.py <qsConfig-ativo>
Imprime linhas C_<NOME>="#rrggbb" para serem avaliadas pelo bash.
end-4   -> ~/.local/state/quickshell/user/generated/colors.json (snake_case, com #)
caelestia -> ~/.local/state/caelestia/scheme.json (camelCase em "colours", sem #)
"""
import sys
import os
import json

active = sys.argv[1] if len(sys.argv) > 1 else ""
home = os.path.expanduser("~")


def norm(c: str) -> str:
    return "#" + c.lstrip("#")


def emit(m: dict) -> None:
    for k, v in m.items():
        print(f'C_{k.upper()}="{norm(v)}"')


try:
    if active == "caelestia":
        d = json.load(open(f"{home}/.local/state/caelestia/scheme.json"))["colours"]
        emit(dict(
            bg=d["surfaceContainer"], bg2=d["surfaceContainerHigh"],
            fg=d["onSurface"], sub=d["onSurfaceVariant"],
            accent=d["primary"], selbg=d["primaryContainer"],
            selfg=d["onPrimaryContainer"], outline=d["outline"],
        ))
    else:
        d = json.load(open(f"{home}/.local/state/quickshell/user/generated/colors.json"))
        emit(dict(
            bg=d["surface_container"], bg2=d["surface_container_high"],
            fg=d["on_surface"], sub=d["on_surface_variant"],
            accent=d["primary"], selbg=d["primary_container"],
            selfg=d["on_primary_container"], outline=d["outline"],
        ))
except Exception:
    # Fallback escuro neutro se algo falhar
    emit(dict(
        bg="1a1a1a", bg2="242424", fg="e0e0e0", sub="a0a0a0",
        accent="8ab4f8", selbg="33425f", selfg="d6e3ff", outline="555555",
    ))
