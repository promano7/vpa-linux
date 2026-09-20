#!/bin/sh
# con-sway.sh - ejecuta una orden dentro de un sway sin pantalla, con un
# puntero virtual vivo (hold-pointer.py), y lo apaga todo al terminar.
# Pareja de con-weston.sh para las pruebas que INYECTAN entrada (Fase 9):
# weston headless no tiene virtual-keyboard ni virtual-pointer; sway si.
#   - teclas:  wtype (protocolo virtual-keyboard)
#   - puntero: swaymsg seat seat0 cursor set X Y   (absoluto)
#              swaymsg seat seat0 cursor press|release button1
# La salida es de 1600x1200 y las ventanas nacen flotantes en (0,0) con el
# tamano que piden, para que haya sitio "fuera de la ventana".
# Deja exportados WAYLAND_DISPLAY y SWAYSOCK para la orden, sin DISPLAY.
#
# Uso:  con-sway.sh ORDEN [ARGUMENTOS...]
# Requisitos: sway, swaymsg, python3 (y wtype para quien lo use).
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d /tmp/con-sway.XXXXXX)"
XDG_RUNTIME_DIR="$tmp/xdg"; export XDG_RUNTIME_DIR
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
unset DISPLAY WAYLAND_DISPLAY SWAYSOCK
cat > "$tmp/sway.conf" <<'EOC'
xwayland disable
output HEADLESS-1 mode 1600x1200 position 0 0
default_border none
focus_follows_mouse no
for_window [app_id=".*"] floating enable, move absolute position 0 0
EOC
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$tmp/sway.conf" >"$tmp/sway.log" 2>&1 &
spid=$!
hpid=
cleanup() {
  [ -n "$hpid" ] && kill "$hpid" 2>/dev/null
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null
  rm -rf "$tmp"
}
fail() { echo "con-sway.sh: $*" >&2; cleanup; exit 1; }

i=0; ready=no
while [ $i -lt 40 ]; do
  kill -0 "$spid" 2>/dev/null || fail "sway ha terminado: $(tail -2 "$tmp/sway.log" | tr '\n' ' ')"
  SWAYSOCK="$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -1)"
  WAYLAND_DISPLAY="$(cd "$XDG_RUNTIME_DIR" && ls wayland-* 2>/dev/null | grep -v lock | head -1)"
  if [ -n "$SWAYSOCK" ] && [ -n "$WAYLAND_DISPLAY" ]; then
    export SWAYSOCK WAYLAND_DISPLAY
    swaymsg -t get_version >/dev/null 2>&1 && { ready=yes; break; }
  fi
  sleep 0.25; i=$((i+1))
done
[ "$ready" = yes ] || fail "sway no arranca: $(tail -2 "$tmp/sway.log" | tr '\n' ' ')"

python3 "$here/hold-pointer.py" >"$tmp/hold.log" 2>&1 &
hpid=$!
i=0
while [ $i -lt 20 ] && ! grep -q ready "$tmp/hold.log" 2>/dev/null; do
  kill -0 "$hpid" 2>/dev/null || fail "hold-pointer.py: $(tail -1 "$tmp/hold.log")"
  sleep 0.25; i=$((i+1))
done
grep -q ready "$tmp/hold.log" || fail "hold-pointer.py no ha creado el puntero virtual"

"$@"
rc=$?
cleanup
exit $rc
