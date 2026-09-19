#!/bin/sh
# Prototipos de la Fase 7 (desechable): ejecuta una orden dentro de un
# compositor Wayland sin pantalla (weston --backend=headless) y SIN DISPLAY,
# para que nada pueda caer a X11/XWayland sin que se note.
#   uso: TESTS/fase7/con-weston.sh orden [argumentos...]
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-fase7}; export XDG_RUNTIME_DIR
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
sock=wl-fase7-$$
weston --backend=headless --socket="$sock" --width=1280 --height=1024 \
       --idle-time=0 >"$XDG_RUNTIME_DIR/weston-$$.log" 2>&1 &
wpid=$!
i=0
while [ ! -S "$XDG_RUNTIME_DIR/$sock" ] && [ $i -lt 50 ]; do
  sleep 0.1; i=$((i+1))
done
env -u DISPLAY WAYLAND_DISPLAY="$sock" "$@"
rc=$?
kill $wpid 2>/dev/null; wait $wpid 2>/dev/null
exit $rc
