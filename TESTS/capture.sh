#!/bin/bash
#
# capture.sh - Captura las escenas de referencia de docs/reference-scenes.md.
#
# Tareas T0.5 y T0.6 de WAYLAND.md. Para cada escena arranca un VPA nuevo sobre
# una copia limpia de la partida de referencia, inyecta la secuencia de teclas
# con xdotool y dispara el volcado de framebuffer (Ctrl-F12, T0.4).
#
# Uso
# ---
#     TESTS/capture.sh DESTINO [ESCENA...]
#
# DESTINO es el directorio donde se dejan los .ppm/.pal (se crea). Sin ESCENA
# se capturan todas; con una o varias (E06 E17) solo esas.
#
# Variables de entorno
# --------------------
#     VPA_BIN      ejecutable de VPA        (por defecto build/VPA)
#     VPA_FIXTURE  partida de referencia    (por defecto TESTS/fixture)
#     VPA_RACE     numero de raza           (por defecto el de RACE, abajo)
#     VPA_DISPLAY  display de Xvfb          (por defecto :99)
#     VPA_KEYWAIT  segundos entre teclas    (por defecto 1.0)
#
# Requisitos: Xvfb, xdotool, y un binario compilado con el volcado de T0.4.
#
# Las condiciones de captura (VPA_SCALE=1, sin gestor de ventanas, puntero
# aparcado en (600,300), copia limpia por escena) estan justificadas en
# docs/reference-scenes.md, seccion 1. No las cambies aqui sin cambiarlas alli.
#

set -u

RACE=9                      # The Robots, turno 90 (partida de TESTS/fixture)
PARK_X=600; PARK_Y=300      # puntero aparcado: dentro del mapa, fuera del panel

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VPA_BIN="${VPA_BIN:-$ROOT/build/VPA}"
VPA_FIXTURE="${VPA_FIXTURE:-$ROOT/TESTS/fixture}"
VPA_RACE="${VPA_RACE:-$RACE}"
VPA_DISPLAY="${VPA_DISPLAY:-:99}"
VPA_KEYWAIT="${VPA_KEYWAIT:-1.0}"

# Catalogo: id|teclas (notacion xdotool, separadas por espacios)|puntero final
# El puntero final es "park" (vuelve a (600,300)) o "X,Y" (se queda ahi).
# Debe coincidir con la tabla de docs/reference-scenes.md, seccion 3.
SCENES='
E01||park
E02|Tab|park
E03|ctrl+Tab|park
E04|F1|park
E05|F1 F1|park
E06|s|park
E07|p|park
E08|b|park
E09|F3|park
E10|ctrl+o|park
E11|F5|park
E12|F10|park
E13|ctrl+F10|park
E14|ctrl+F11|park
E15|F6|park
E16|b b|park
E17|Return space|300,200
E18|Return|park
E19|l|park
E20|F1 c|park
'

die() { echo "capture.sh: $*" >&2; exit 2; }

[ $# -ge 1 ] || die "uso: $0 DESTINO [ESCENA...]"
OUT="$1"; shift
WANTED="$*"

for tool in Xvfb xdotool; do
  command -v "$tool" >/dev/null 2>&1 || die "falta $tool"
done
[ -x "$VPA_BIN" ] || die "no hay ejecutable en $VPA_BIN (make build)"
[ -d "$VPA_FIXTURE" ] || die "no hay partida de referencia en $VPA_FIXTURE"

mkdir -p "$OUT" || die "no se puede crear $OUT"
OUT="$(cd "$OUT" && pwd)"
TMP="$(mktemp -d)"
trap 'kill "${XVFB_PID:-}" 2>/dev/null; rm -rf "$TMP"' EXIT

# Xvfb propio, sin gestor de ventanas: la ventana de VPA aparece en (0,0).
Xvfb "$VPA_DISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY="$VPA_DISPLAY"

wait_for_window() {
  local n=0 w=""
  while [ $n -lt 30 ]; do
    w="$(xdotool search --onlyvisible --name . 2>/dev/null | head -1)"
    [ -n "$w" ] && { echo "$w"; return 0; }
    sleep 0.5; n=$((n+1))
  done
  return 1
}

wait_for_file() {
  local n=0
  while [ $n -lt 40 ]; do
    [ -s "$1" ] && return 0
    sleep 0.25; n=$((n+1))
  done
  return 1
}

capture_scene() {
  local id="$1" keys="$2" pointer="$3" game="$TMP/game" win app rc=0

  rm -rf "$game"
  cp -r "$VPA_FIXTURE" "$game" || return 2
  rm -f "$OUT/$id-"*.ppm "$OUT/$id-"*.pal

  VPA_SCALE=1 VPA_GRAPH_DUMP="$OUT/$id-" \
    "$VPA_BIN" "$VPA_RACE" "$game" >"$OUT/$id.log" 2>&1 &
  app=$!
  sleep 3

  if ! win="$(wait_for_window)"; then
    echo "$id: no aparece la ventana (ver $OUT/$id.log)" >&2
    kill "$app" 2>/dev/null; return 1
  fi

  xdotool mousemove --window "$win" "$PARK_X" "$PARK_Y"; sleep 0.5
  for k in $keys; do
    xdotool key --window "$win" --clearmodifiers "$k"
    sleep "$VPA_KEYWAIT"
  done
  case "$pointer" in
    park) xdotool mousemove --window "$win" "$PARK_X" "$PARK_Y" ;;
    *)    xdotool mousemove --window "$win" "${pointer%,*}" "${pointer#*,}" ;;
  esac
  sleep 0.5
  xdotool key --window "$win" --clearmodifiers ctrl+F12

  if wait_for_file "$OUT/$id-0001.ppm"; then
    echo "$id: ok"
  else
    echo "$id: no se ha producido el volcado (ver $OUT/$id.log)" >&2; rc=1
  fi
  kill "$app" 2>/dev/null; wait "$app" 2>/dev/null
  return $rc
}

failed=0
while IFS='|' read -r id keys pointer; do
  [ -z "$id" ] && continue
  if [ -n "$WANTED" ] && ! [[ " $WANTED " == *" $id "* ]]; then continue; fi
  capture_scene "$id" "$keys" "$pointer" || failed=$((failed+1))
done <<< "$SCENES"

if [ $failed -eq 0 ]; then
  echo "todas las escenas capturadas en $OUT"
else
  echo "$failed escena(s) han fallado" >&2
  exit 1
fi
