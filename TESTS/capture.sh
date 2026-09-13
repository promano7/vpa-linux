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
#     VPA_BIN       ejecutable de VPA        (por defecto build/VPA)
#     VPA_FIXTURE   partida de referencia    (por defecto TESTS/fixture)
#     VPA_RESOURCE  ruta de RESOURCE.PLN     (por defecto se busca, ver abajo)
#     VPA_RACE      numero de raza           (por defecto el de RACE, abajo)
#     VPA_DISPLAY   display de Xvfb          (por defecto :99)
#     VPA_KEYWAIT   segundos entre teclas    (por defecto 1.0)
#     VPA_KEYMODE   xtest | sendevent        (por defecto xtest)
#
# Requisitos: Xvfb, xdotool, y un binario compilado con el volcado de T0.4.
#
# Las condiciones de captura (VPA_SCALE=1, sin gestor de ventanas, puntero
# aparcado en (240,240), copia limpia por escena, directorio de ejecucion
# propio, salvapantallas apagado) estan justificadas en
# docs/reference-scenes.md, seccion 1. No las cambies aqui sin cambiarlas alli.
#
# El directorio de ejecucion
# --------------------------
# VPA busca VPA.HLP, RESOURCE.PLN, DISTTABL.DAT, VPA.MSG y LITT_VPA.CHR en el
# DIRECTORIO ACTUAL, no en el de la partida (VPA/VPADATA.PAS: OpenFile usa el
# nombre tal cual y OpenData prueba primero addir y luego el nombre pelado).
# VPA.HLP, RESOURCE.PLN y DISTTABL.DAT son obligatorios y VPA aborta si no los
# encuentra, antes de abrir la ventana; ese aborto se veia aqui como "no aparece
# la ventana", que es el sintoma equivocado. Asi que el guion no depende de
# donde lo lances: monta un directorio de ejecucion propio en un temporal con
# enlaces a esos ficheros, comprueba que estan ANTES de arrancar nada, y lanza
# VPA desde ahi.
#
# El VPA.INI de ese directorio es una copia de VPA/VPA.INI (el del repositorio,
# versionado) con ScreenSaverTime = 0. Dos motivos: la configuracion de las
# doradas queda fijada por el repositorio y no por el ~/PLANETS de quien
# capture, y el salvapantallas de VPA no se dispara en mitad de una espera.
# VPA/VPA.INI trae ScreenSaverTime = 1, o sea un minuto, y una escena de varias
# teclas a un segundo por tecla lo alcanza; cuando salta, SCRSAVER repinta la
# pantalla y el volcado sale con el salvapantallas encima.
#

set -u

RACE=9                      # The Robots, turno 90 (partida de TESTS/fixture)
PARK_X=240; PARK_Y=240      # puntero aparcado: centro del mapa, lejos del borde
                            # (ver docs/reference-scenes.md, seccion 1: fuera de
                            #  8..471 x 8..477 VPA entra en auto-scroll y deja de
                            #  leer el teclado)
PAL_BYTES=768               # tamano final del .pal: 256 tripletes RGB
ADDIR_MAX=65                # addir es string[67] y aun guarda el separador final

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VPA_BIN="${VPA_BIN:-$ROOT/build/VPA}"
VPA_FIXTURE="${VPA_FIXTURE:-$ROOT/TESTS/fixture}"
VPA_RACE="${VPA_RACE:-$RACE}"
VPA_DISPLAY="${VPA_DISPLAY:-:99}"
VPA_KEYWAIT="${VPA_KEYWAIT:-1.0}"
VPA_KEYMODE="${VPA_KEYMODE:-xtest}"
VPA_RESOURCE="${VPA_RESOURCE:-}"

# Catalogo: id|teclas (notacion xdotool, separadas por espacios)|puntero final
# Un elemento "@X,Y" en la lista de teclas no es una tecla: mueve el puntero a
# (X,Y) de la ventana antes de la tecla siguiente (E06 lo usa para poner el
# puntero sobre una nave y seleccionarla con Return).
# El puntero final es "park" (vuelve a (240,240)) o "X,Y" (se queda ahi).
# Debe coincidir con la tabla de docs/reference-scenes.md, seccion 3.
SCENES='
E01||park
E02|Tab|park
E03|ctrl+Tab|park
E04|F1|park
E05|F1 F1|park
E06|@71,464 Return|71,464
E07|@382,213 Return|382,213
E08|b|park
E09|F3|park
E10|ctrl+o|park
E11|F5|park
E12|F10|park
E13|ctrl+F10 c n m a d s f e u o|park
E14|ctrl+F11|park
E15|F6|park
E16|b b|park
E17|Return space|300,200
E18|1|park
E19|F1 space l|park
E20|F1 space c|park
'

die()  { echo "capture.sh: $*" >&2; exit 2; }
warn() { echo "capture.sh: aviso: $*" >&2; }

[ $# -ge 1 ] || die "uso: $0 DESTINO [ESCENA...]"
OUT="$1"; shift
WANTED="$*"

case "$VPA_KEYMODE" in
  xtest|sendevent) ;;
  *) die "VPA_KEYMODE debe ser xtest o sendevent (es '$VPA_KEYMODE')" ;;
esac

for tool in Xvfb xdotool; do
  command -v "$tool" >/dev/null 2>&1 || die "falta $tool"
done
[ -x "$VPA_BIN" ] || die "no hay ejecutable en $VPA_BIN (make build)"
[ -d "$VPA_FIXTURE" ] || die "no hay partida de referencia en $VPA_FIXTURE"

mkdir -p "$OUT" || die "no se puede crear $OUT"
OUT="$(cd "$OUT" && pwd)"
TMP="$(mktemp -d)"
trap 'kill "${XVFB_PID:-}" 2>/dev/null; rm -rf "$TMP"' EXIT

# --- directorio de ejecucion --------------------------------------------------

RUN="$TMP/run"
mkdir -p "$RUN" || die "no se puede crear $RUN"

# find_file NOMBRE DIR... -> imprime la primera ruta existente (tolera la caja)
find_file() {
  local name="$1"; shift
  local d p
  for d in "$@"; do
    [ -d "$d" ] || continue
    for p in "$d/$name" "$d/$(echo "$name" | tr 'A-Z' 'a-z')"; do
      [ -f "$p" ] && { echo "$p"; return 0; }
    done
  done
  return 1
}

# need_file NOMBRE "de donde sale" DIR...   (obligatorio: si falta, se para)
need_file() {
  local name="$1" hint="$2"; shift 2
  local p
  if p="$(find_file "$name" "$@")"; then
    ln -sf "$p" "$RUN/$name"
  else
    die "no encuentro $name (mirado en: $*). $hint"
  fi
}

# want_file NOMBRE DIR...                   (opcional: si falta, solo avisa)
want_file() {
  local name="$1"; shift
  local p
  if p="$(find_file "$name" "$@")"; then
    ln -sf "$p" "$RUN/$name"
  else
    warn "no encuentro $name (opcional), mirado en: $*"
  fi
}

need_file VPA.HLP \
  "Se genera con 'make hlp' desde VHLP/VPA.HHH." \
  "$ROOT/build" "$ROOT"
need_file DISTTABL.DAT \
  "Viene en el repositorio; si falta, el arbol esta incompleto." \
  "$ROOT" "$ROOT/build"

if [ -n "$VPA_RESOURCE" ]; then
  [ -f "$VPA_RESOURCE" ] || die "VPA_RESOURCE no apunta a un fichero: $VPA_RESOURCE"
  ln -sf "$VPA_RESOURCE" "$RUN/RESOURCE.PLN"
else
  need_file RESOURCE.PLN \
    "No esta en el repositorio (es de VGA Planets): copialo de tu instalacion o pasa la ruta en VPA_RESOURCE." \
    "$ROOT" "$ROOT/build" "$VPA_FIXTURE" "$HOME/PLANETS"
fi

want_file VPA.MSG      "$ROOT" "$ROOT/build"
want_file LITT_VPA.CHR "$ROOT/build" "$ROOT"

# VPA.INI del repositorio, con el salvapantallas desactivado.
[ -f "$ROOT/VPA/VPA.INI" ] || die "falta $ROOT/VPA/VPA.INI, la configuracion de referencia"
if grep -qi '^[[:space:]]*ScreenSaverTime' "$ROOT/VPA/VPA.INI"; then
  sed 's/^[[:space:]]*[Ss][Cc][Rr][Ee][Ee][Nn][Ss][Aa][Vv][Ee][Rr][Tt][Ii][Mm][Ee].*$/ScreenSaverTime        = 0/' \
    "$ROOT/VPA/VPA.INI" > "$RUN/VPA.INI"
else
  { cat "$ROOT/VPA/VPA.INI"; printf '\n[Interface]\nScreenSaverTime = 0\n'; } > "$RUN/VPA.INI"
fi
grep -qi '^ScreenSaverTime[[:space:]]*=[[:space:]]*0[[:space:]]*$' "$RUN/VPA.INI" ||
  die "no he podido desactivar ScreenSaverTime en $RUN/VPA.INI"

# --- servidor X ---------------------------------------------------------------

# Xvfb propio, sin gestor de ventanas: la ventana de VPA aparece en (0,0).
# '-s 0' apaga el salvapantallas del servidor. No afecta al volcado (que sale de
# la superficie de ptc, no del servidor), pero evita que xdotool tenga que
# despertar la pantalla en mitad de una escena.
Xvfb "$VPA_DISPLAY" -screen 0 1024x768x24 -s 0 >"$TMP/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY="$VPA_DISPLAY"

# Esperar a que el servidor acepte conexiones, no un 'sleep' a ojo: con una
# espera fija la primera escena arranca antes de que Xvfb este escuchando, VPA
# muere con "no display" y solo falla esa, que es un fallo desconcertante.
xvfb_ready=no
for _ in $(seq 1 40); do
  kill -0 "$XVFB_PID" 2>/dev/null ||
    die "Xvfb ha terminado: $(tail -2 "$TMP/xvfb.log" | tr '\n' ' ')"
  if xdotool getdisplaygeometry >/dev/null 2>&1; then xvfb_ready=yes; break; fi
  sleep 0.25
done
[ "$xvfb_ready" = yes ] ||
  die "Xvfb no acepta conexiones en $VPA_DISPLAY: $(tail -2 "$TMP/xvfb.log" | tr '\n' ' ')"
command -v xset >/dev/null 2>&1 && xset s off -dpms >/dev/null 2>&1

# El titulo de la ventana es ParamStr(0) (VENDOR/ptcgraph.pp, WindowTitle), o
# sea la ruta exacta con la que lanzamos el binario. Buscar por ella en vez de
# por "cualquier ventana visible" evita quedarse con una ventana ajena.
TITLE_RE="^$(printf '%s' "$VPA_BIN" | sed 's/[][\\.*^$+?(){}|]/\\&/g')\$"

wait_for_window() {
  local pid="$1" n=0 w=""
  while [ $n -lt 60 ]; do
    kill -0 "$pid" 2>/dev/null || return 2      # ha muerto antes de abrir
    w="$(xdotool search --onlyvisible --name "$TITLE_RE" 2>/dev/null | head -1)"
    [ -n "$w" ] && { echo "$w"; return 0; }
    sleep 0.5; n=$((n+1))
  done
  return 1
}

# El .pal se escribe despues del .ppm y cierra el volcado (VENDOR/ptcgraph.pp,
# VPADumpFrame), asi que esperar a que tenga sus 768 bytes garantiza que el
# .ppm ya esta entero en disco.
wait_for_dump() {
  local pal="$1" n=0
  while [ $n -lt 60 ]; do
    if [ -f "$pal" ] && [ "$(stat -c %s "$pal" 2>/dev/null || echo 0)" -eq "$PAL_BYTES" ]; then
      return 0
    fi
    sleep 0.25; n=$((n+1))
  done
  return 1
}

send_key() {
  local win="$1" key="$2"
  if [ "$VPA_KEYMODE" = xtest ]; then
    xdotool key --clearmodifiers "$key"
  else
    xdotool key --window "$win" --clearmodifiers "$key"
  fi
}

# --- captura ------------------------------------------------------------------

capture_scene() {
  local id="$1" keys="$2" pointer="$3" game="$TMP/game" win app rc=0 k gini

  rm -rf "$game"
  cp -r "$VPA_FIXTURE" "$game" || return 2
  rm -f "$OUT/$id-"*.ppm "$OUT/$id-"*.pal

  # Por si una partida futura trae su propio VPA.INI: el del directorio de la
  # partida se lee DESPUES del del directorio actual y lo pisa (VPA/CONFIG.PAS,
  # ReadConfig1), asi que hay que desactivar el salvapantallas ahi tambien.
  gini="$(find_file VPA.INI "$game" || true)"
  if [ -n "$gini" ]; then
    if grep -qi '^[[:space:]]*ScreenSaverTime' "$gini"; then
      sed -i 's/^[[:space:]]*[Ss][Cc][Rr][Ee][Ee][Nn][Ss][Aa][Vv][Ee][Rr][Tt][Ii][Mm][Ee].*$/ScreenSaverTime        = 0/' "$gini"
    else
      printf '\n[Interface]\nScreenSaverTime = 0\n' >> "$gini"
    fi
  fi

  if [ ${#game} -gt $ADDIR_MAX ]; then
    echo "$id: la ruta de la partida ($game) pasa de $ADDIR_MAX caracteres y VPA la rechaza" >&2
    return 1
  fi

  # VISUAL fija la etiqueta "Edit file with 'nano'" del menu Ctrl-O (E10):
  # VPA/INI.PAS resuelve $VISUAL, luego $EDITOR, luego nano y vi en el PATH, y
  # sin ninguno escribe 'no editor found', asi que la escena dependia de la
  # maquina. Una ruta con barra se acepta tal cual, exista o no.
  ( cd "$RUN" && exec env VPA_SCALE=1 VPA_GRAPH_DUMP="$OUT/$id-" \
      VISUAL=/usr/bin/nano \
      "$VPA_BIN" "$VPA_RACE" "$game" ) >"$OUT/$id.log" 2>&1 &
  app=$!

  win="$(wait_for_window "$app")"
  case $? in
    2) echo "$id: VPA ha terminado sin abrir la ventana: $(tail -3 "$OUT/$id.log" | tr '\n' ' ')" >&2
       return 1 ;;
    1) echo "$id: la ventana no ha aparecido en 30 s (ver $OUT/$id.log)" >&2
       kill "$app" 2>/dev/null; wait "$app" 2>/dev/null; return 1 ;;
  esac

  # Sin gestor de ventanas nadie reparte el foco: se lo damos nosotros, que es
  # lo que necesita xdotool en modo xtest (la tecla va a la ventana con foco).
  xdotool windowfocus --sync "$win" 2>/dev/null
  xdotool mousemove --window "$win" "$PARK_X" "$PARK_Y"; sleep 0.5

  for k in $keys; do
    case "$k" in
      @*) k="${k#@}"; xdotool mousemove --window "$win" ${k//,/ }; sleep 0.5 ;;
      *)  send_key "$win" "$k"
          sleep "$VPA_KEYWAIT" ;;
    esac
  done
  case "$pointer" in
    park) xdotool mousemove --window "$win" "$PARK_X" "$PARK_Y" ;;
    *)    xdotool mousemove --window "$win" "${pointer%,*}" "${pointer#*,}" ;;
  esac
  sleep 0.5
  send_key "$win" ctrl+F12

  if wait_for_dump "$OUT/$id-0001.pal"; then
    echo "$id: ok"
  else
    echo "$id: no se ha producido el volcado (ver $OUT/$id.log)" >&2; rc=1
  fi
  kill "$app" 2>/dev/null; wait "$app" 2>/dev/null
  return $rc
}

# Un arranque de VPA de cada veinte muere en TX11Console.CreateDisplay con
# 'Cannot open X display': XOpenDisplay falla al encadenar arranques y muertes
# de proceso contra el mismo servidor. No es de la escena ni del dibujo, asi que
# se le da un respiro al servidor entre escenas y se reintenta una vez, con
# aviso: si una escena necesita el reintento siempre, eso ya no es esto.
failed=0
while IFS='|' read -r id keys pointer; do
  [ -z "$id" ] && continue
  if [ -n "$WANTED" ] && ! [[ " $WANTED " == *" $id "* ]]; then continue; fi
  if ! capture_scene "$id" "$keys" "$pointer"; then
    echo "$id: reintentando" >&2
    sleep 2
    capture_scene "$id" "$keys" "$pointer" || failed=$((failed+1))
  fi
  sleep 0.5
done <<< "$SCENES"

if [ $failed -eq 0 ]; then
  echo "todas las escenas capturadas en $OUT"
else
  echo "$failed escena(s) han fallado" >&2
  exit 1
fi
