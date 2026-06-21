#!/usr/bin/env bash
#
# setup-env.sh — Fase 0 del port de VPA a GNU/Linux
#
# Instala Free Pascal y las units graficas (ptcgraph/ptccrt/ptcmouse) y verifica
# que el entorno esta listo para compilar el port.
#
# Probado: partes genericas (verificacion de units + prueba de compilacion) en FPC 3.2.2
# sobre Ubuntu 24.04. Comandos de instalacion por distro segun su empaquetado de FPC.
#
set -euo pipefail

echo "==> VPA-Linux: verificacion del entorno (Fase 0)"
echo

# --- 1. Detectar gestor de paquetes e instalar FPC + gcc + units/librerias ---
# IMPORTANTE: se ejecuta SIEMPRE (es idempotente con --needed / apt). Asi nos
# aseguramos de instalar gcc y las librerias X aunque FPC ya estuviera presente.
install_deps() {
  if command -v pacman >/dev/null 2>&1; then
    echo "==> Arch Linux detectado. Instalando fpc + gcc + librerias X..."
    # En Arch, las units graficas (ptcgraph/ptccrt/ptcmouse/ptc) vienen DENTRO
    # del paquete 'fpc' (no hay paquete aparte tipo 'fp-units-gfx').
    # 'gcc' aporta los objetos crt*.o que FPC necesita para enlazar.
    # Las librerias X son las que el backend X11 de ptc enlaza (-lX11 -lXext
    # -lXfixes -lXi -lXrandr -lXxf86dga -lXxf86vm). En Arch hay que instalarlas
    # explicitamente; varias ya vienen con el escritorio, '--needed' salta esas.
    # OJO: 'libxxf86dga' ya NO esta en los repos oficiales de Arch (retirado en la
    # limpieza de Xorg de 2019). Se gestiona aparte mas abajo, fuera de esta linea,
    # porque si se incluye aqui pacman aborta toda la transaccion ("paquete no encontrado").
    sudo pacman -S --needed fpc gcc \
      libx11 libxext libxfixes libxi libxrandr libxxf86vm
  elif command -v apt-get >/dev/null 2>&1; then
    echo "==> Debian/Ubuntu detectado. Instalando fpc + fp-units-gfx + librerias X..."
    sudo apt-get update
    # En Debian/Ubuntu las units graficas van en paquete aparte.
    # El metapaquete 'fp-units-gfx' arrastra la version concreta (p.ej. -3.2.2).
    sudo apt-get install -y fpc fp-units-gfx \
      libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxxf86dga-dev libxxf86vm-dev
  elif command -v dnf >/dev/null 2>&1; then
    echo "==> Fedora detectado. Instalando fpc + librerias X..."
    # En Fedora las units graficas suelen venir en el propio paquete fpc.
    sudo dnf install -y fpc gcc \
      libX11-devel libXext-devel libXfixes-devel libXi-devel \
      libXrandr-devel libXxf86dga-devel libXxf86vm-devel
  else
    echo "!! No reconozco el gestor de paquetes. Instala manualmente FPC, gcc y las"
    echo "   librerias de desarrollo de X (X11, Xext, Xfixes, Xi, Xrandr, Xxf86dga,"
    echo "   Xxf86vm) desde tu distro, y vuelve a ejecutar este script."
    exit 1
  fi
}

install_deps

# --- 1b. Caso especial Arch: libXxf86dga (retirada de los repos oficiales) ---
# ptcgraph de FPC 3.2.2 enlaza -lXxf86dga, pero Arch retiro 'libxxf86dga' en 2019.
# Si no esta la libreria, avisamos con la via del Arch Linux Archive.
if command -v pacman >/dev/null 2>&1; then
  if ! ls /usr/lib/libXxf86dga.so* >/dev/null 2>&1; then
    echo
    echo "!! Falta 'libXxf86dga' (ptcgraph la necesita y Arch la retiro de los repos)."
    echo "   Opcion A (AUR):     yay -S libxxf86dga"
    echo "   Opcion B (Archive): sudo pacman -U https://archive.archlinux.org/packages/l/libxxf86dga/libxxf86dga-1.1.5-1-x86_64.pkg.tar.zst"
    echo "   (el Archive es binario, util si la build del AUR falla)"
    echo
  fi
fi

# --- 2. Mostrar version ---
FPCVER="$(fpc -iV 2>/dev/null || echo '???')"
echo "==> Version de FPC: $FPCVER"
echo

# --- 3. Localizar el directorio de units graficas ---
echo "==> Buscando las units graficas..."
GRAPHDIR=""
for ppu in $(find /usr/lib -iname 'ptcgraph.ppu' 2>/dev/null); do
  GRAPHDIR="$(dirname "$ppu")"
  break
done

if [ -z "$GRAPHDIR" ]; then
  echo "!! No encuentro ptcgraph.ppu."
  if command -v pacman >/dev/null 2>&1; then
    echo "   En Arch deberian venir con 'fpc'. Comprueba la instalacion con:"
    echo "     pacman -Ql fpc | grep ptcgraph"
  else
    echo "   En Debian/Ubuntu instala el paquete versionado:"
    echo "     sudo apt-get install fp-units-gfx-${FPCVER}"
  fi
  exit 1
fi
echo "    Directorio de units: $GRAPHDIR"
echo

# --- 4. Verificar las 4 units que necesita el port ---
echo "==> Comprobando units necesarias:"
MISSING=0
for u in ptcgraph ptccrt ptcmouse ptc; do
  if find /usr/lib -iname "$u.ppu" 2>/dev/null | grep -q .; then
    echo "    [OK]    $u"
  else
    echo "    [FALTA] $u"
    MISSING=1
  fi
done
echo

# --- 5. Prueba real de compilacion ---
echo "==> Prueba de compilacion con ptcgraph..."
TMP="$(mktemp -d)"
cat > "$TMP/gtest.pas" <<'EOF'
program gtest;
uses ptcgraph, ptccrt;
var gd, gm: smallint;
begin
  gd := D8bit; gm := m640x480;
  InitGraph(gd, gm, '');
  if GraphResult <> grOk then Halt(1);
  SetColor(White); Line(0,0,100,100);
  CloseGraph;
end.
EOF

# Capturamos la salida para mostrarla SOLO si algo falla (asi vemos el error real)
BUILD_LOG="$TMP/build.log"
if fpc -Fu"$GRAPHDIR" "$TMP/gtest.pas" >"$BUILD_LOG" 2>&1 && [ -x "$TMP/gtest" ]; then
  echo "    [OK] El toolchain compila y enlaza programas ptcgraph."
else
  echo "    [ERROR] No se pudo compilar/enlazar la prueba. Salida del compilador:"
  echo "    ----------------------------------------------------------------"
  sed 's/^/    /' "$BUILD_LOG"
  echo "    ----------------------------------------------------------------"
  echo "    Pista: si ves 'cannot find -lXxf86dga', en Arch instala esa libreria"
  echo "    desde el Arch Linux Archive (ya no esta en los repos):"
  echo "       sudo pacman -U https://archive.archlinux.org/packages/l/libxxf86dga/libxxf86dga-1.1.5-1-x86_64.pkg.tar.zst"
  echo "    Si falta otra '-lX...': sudo pacman -S --needed libxext libxfixes libxi libxrandr libxxf86vm"
  MISSING=1
fi
rm -rf "$TMP"
echo

# --- 6. Resumen ---
if [ "$MISSING" -eq 0 ]; then
  echo "======================================================"
  echo " ENTORNO LISTO. Anota esta ruta para el Makefile/fpc.cfg:"
  echo "   $GRAPHDIR"
  echo "======================================================"
else
  echo "!! Faltan componentes. Revisa los mensajes [FALTA]/[ERROR] de arriba."
  exit 1
fi
