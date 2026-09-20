#!/bin/bash
# ============================================================================
# vpa-chroot-bookworm.sh  (se usa a traves de vpa-chroot-bookworm-arm64.sh y
#                          vpa-chroot-bookworm-amd64.sh, que le pasan la
#                          arquitectura como primer argumento)
#
# Monta y reutiliza un chroot de Debian 12 (bookworm) en un anfitrion Arch
# Linux, y construye dentro el paquete distribuible de VPA-Linux ('make data')
# con el nombre de las publicaciones: vpa-linux-<version>-<arch>.tar.gz, que se
# descomprime en vpa-linux-<version>-<arch>/. La version se lee de
# VPA/VPADATA.PAS en la rama que se construye. Se compila en bookworm para que
# los binarios pidan una glibc antigua y el paquete sirva en bookworm y en todo
# lo posterior (BUILD.es.md, seccion 4.1).
#
# Uso (como root, o con sudo); <script> es el de arm64 o el de amd64:
#   sudo <script>                       # = build main
#   sudo <script> build [ref]           # rama, etiqueta o commit, p. ej.
#                                       #   build feature/wayland
#                                       #   build 3.67.5     (rama de version)
#                                       #   build v3.67.5    (etiqueta)
#   sudo <script> setup                 # solo crear el chroot
#   sudo <script> update                # apt upgrade dentro
#   sudo <script> shell                 # entrar al chroot
#   sudo <script> clean-sdl3            # rehacer la SDL3 en el proximo build
#   sudo <script> destroy               # borrar el chroot entero
#   <script> help
#
# La primera vez 'build' crea el chroot (unos minutos). Las siguientes lo
# reutiliza: el clon del repo y build/sdl3/ (la SDL3 ya compilada) se quedan
# dentro, asi que un build repetido solo recompila VPA y los plugins.
# Vale tambien para las ramas anteriores a los plugins (3.67.2 a 3.67.5), cuyo
# 'make data' no lleva SDL3 y necesita xvfb, que esta instalado en el chroot.
#
# Variables de entorno:
#   VPA_CHROOT  directorio del chroot   (por defecto /srv/chroot/vpa-bookworm-<arch>)
#   VPA_REPO    de donde clonar: una URL, o un directorio local con el repo
#               (por defecto https://github.com/promano7/vpa-linux.git).
#               Con un directorio local se construyen commits sin subir, pero
#               solo se ven sus ramas LOCALES:
#               sudo VPA_REPO=~/GitHub/vpa-linux <script> build main
#   VPA_OUT     donde dejar el tarball  (por defecto el directorio actual)
#   VPA_MIRROR  replica de Debian       (por defecto http://deb.debian.org/debian)
#
# Paquetes del anfitrion (Arch):
#   sudo pacman -S debootstrap debian-archive-keyring
#   y ademas, solo para arm64:  qemu-user-static qemu-user-static-binfmt
# ============================================================================
set -euo pipefail

ARCH="${1:-}"               # arquitectura de Debian: arm64 | amd64
[ $# -gt 0 ] && shift
SUITE=bookworm

case "$ARCH" in
  arm64) MACHINE=aarch64 ;;
  amd64) MACHINE=x86_64 ;;
  *) echo "uso: $0 arm64|amd64 [build [ref] | setup | update | shell | clean-sdl3 | destroy | help]" >&2; exit 2 ;;
esac

CHROOT="${VPA_CHROOT:-/srv/chroot/vpa-$SUITE-$ARCH}"
REPO="${VPA_REPO:-https://github.com/promano7/vpa-linux.git}"
OUT="$(realpath "${VPA_OUT:-$PWD}")"
MIRROR="${VPA_MIRROR:-http://deb.debian.org/debian}"

# Lo que necesita 'make data' (BUILD.es.md, seccion 7, bloque de Debian), mas
# git, certificados y binutils (objdump) para la comprobacion de glibc, y xvfb
# y xauth para el 'make hlp' de las ramas anteriores a la Fase 6.
PKGS="git ca-certificates make binutils fpc xvfb xauth \
libx11-dev libxext-dev libxfixes-dev libxrandr-dev libxi-dev libxxf86vm-dev \
curl cmake gcc libc6-dev pkg-config libwayland-dev wayland-protocols \
libxkbcommon-dev libdecor-0-dev libegl1-mesa-dev libgles2-mesa-dev"

say() { printf '\n>> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in -h|--help|help) sed -n '2,/^# =\{20,\}$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
[ "$(id -u)" -eq 0 ] || die "hay que ejecutarlo como root: sudo $0 $*"

check_host() {
  command -v debootstrap   >/dev/null || die "falta debootstrap (pacman -S debootstrap debian-archive-keyring)"
  command -v systemd-nspawn >/dev/null || die "falta systemd-nspawn"
  if [ "$MACHINE" != "$(uname -m)" ]; then
    # Arquitectura ajena: hace falta qemu-user-static registrado en binfmt_misc.
    if [ ! -e "/proc/sys/fs/binfmt_misc/qemu-$MACHINE" ]; then
      systemctl restart systemd-binfmt 2>/dev/null || true
    fi
    [ -e "/proc/sys/fs/binfmt_misc/qemu-$MACHINE" ] || die \
      "qemu-$MACHINE no esta registrado en binfmt_misc: pacman -S qemu-user-static qemu-user-static-binfmt && systemctl restart systemd-binfmt"
    grep -q '^flags:.*F' "/proc/sys/fs/binfmt_misc/qemu-$MACHINE" || die \
      "qemu-$MACHINE esta registrado sin la bandera F (fix-binary); el chroot no encontraria el interprete"
  fi
}

# Ejecuta una orden dentro del chroot. Argumentos extra de nspawn en NSPAWN_EXTRA.
NSPAWN_EXTRA=()
in_chroot() {
  systemd-nspawn -q -D "$CHROOT" --as-pid2 --setenv=DEBIAN_FRONTEND=noninteractive \
                 --setenv=LC_ALL=C.UTF-8 "${NSPAWN_EXTRA[@]}" "$@"
}

do_setup() {
  check_host
  if [ -x "$CHROOT/usr/bin/apt-get" ] && [ -e "$CHROOT/.vpa-chroot-ready" ]; then
    return 0
  fi
  [ ! -e "$CHROOT" ] || [ -z "$(ls -A "$CHROOT" 2>/dev/null)" ] || die \
    "$CHROOT existe y no es un chroot terminado: borralo ($0 destroy) y repite"
  say "Creando el chroot $SUITE/$ARCH en $CHROOT"
  mkdir -p "$CHROOT"
  debootstrap --arch="$ARCH" --variant=minbase "$SUITE" "$CHROOT" "$MIRROR"
  # Actualizaciones de seguridad y de punto, ademas del archivo base.
  cat > "$CHROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $SUITE main
deb $MIRROR $SUITE-updates main
deb http://security.debian.org/debian-security $SUITE-security main
EOF
  say "Instalando las dependencias de compilacion"
  in_chroot apt-get update
  in_chroot apt-get -y upgrade
  # shellcheck disable=SC2086
  in_chroot apt-get -y install --no-install-recommends $PKGS
  in_chroot apt-get clean
  [ "$(in_chroot uname -m | tr -d '\r')" = "$MACHINE" ] || die "el chroot no es $MACHINE"
  touch "$CHROOT/.vpa-chroot-ready"
  say "Chroot listo: $CHROOT"
}

do_update() {
  do_setup
  say "Actualizando los paquetes del chroot"
  in_chroot apt-get update
  in_chroot apt-get -y upgrade
  # shellcheck disable=SC2086
  in_chroot apt-get -y install --no-install-recommends $PKGS
  in_chroot apt-get clean
}

do_build() {
  local ref="${1:-main}" src tarball
  do_setup
  mkdir -p "$OUT"
  NSPAWN_EXTRA=(--bind="$OUT":/out)
  if [ -d "$REPO" ]; then
    # Repo local: se monta en solo lectura y se clona desde ahi.
    NSPAWN_EXTRA+=(--bind-ro="$(realpath "$REPO")":/src)
    src=/src
  else
    src="$REPO"
  fi
  # El guion que corre DENTRO del chroot.
  cat > "$CHROOT/root/vpa-build.sh" <<'EOS'
#!/bin/bash
set -euo pipefail
ref="$1"; src="$2"; machine="$3"
rm -f /root/.vpa-last-tarball
git config --global --add safe.directory "*"
[ -d /root/vpa-linux/.git ] || git clone "$src" /root/vpa-linux
cd /root/vpa-linux
git remote set-url origin "$src"
git fetch --tags --prune origin
# Rama remota si existe; si no, etiqueta o commit tal cual.
if git rev-parse -q --verify "origin/$ref^{commit}" >/dev/null; then
  git checkout -q -f --detach "origin/$ref"
else
  git checkout -q -f --detach "$ref"
fi
echo ">> HEAD: $(git log -1 --format='%h %s')"
ver="$(sed -n "s/^const[[:space:]]*Version[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p" VPA/VPADATA.PAS | head -1)"
[ -n "$ver" ] || { echo "ERROR: no encuentro 'const Version' en VPA/VPADATA.PAS" >&2; exit 1; }
pkg="vpa-linux-$ver-$machine"
echo ">> Version $ver -> $pkg.tar.gz"
make clean                       # conserva build/sdl3/
make data
[ -d build/vpa-linux_package ] || {
  echo "ERROR: el 'make data' de '$ref' no monta build/vpa-linux_package/ (rama demasiado antigua)" >&2; exit 1; }
echo
echo ">> glibc minima que pide cada binario del paquete:"
( cd build/vpa-linux_package
  shopt -s nullglob
  for f in VPA plugins/*.so*; do
    printf "   %-34s %s\n" "$f" \
      "$(objdump -T "$f" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
  done )
# Mismo nombre y mismo directorio raiz que los tarballs publicados.
tar -czf "/out/$pkg.tar.gz" --owner=0 --group=0 \
    --transform "s,^vpa-linux_package,$pkg," -C build vpa-linux_package
echo "$pkg.tar.gz" > /root/.vpa-last-tarball
EOS
  say "Construyendo '$ref' de $REPO para $MACHINE"
  in_chroot /bin/bash /root/vpa-build.sh "$ref" "$src" "$MACHINE"
  tarball="$(cat "$CHROOT/root/.vpa-last-tarball")"
  # Que el tarball sea del usuario que llamo a sudo, no de root.
  if [ -n "${SUDO_UID:-}" ]; then
    chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$OUT/$tarball"
  fi
  say "Hecho: $OUT/$tarball"
}

case "${1:-build}" in
  setup)      do_setup ;;
  update)     do_update ;;
  build)      shift || true; do_build "${1:-main}" ;;
  shell)      do_setup; say "Dentro del chroot ($SUITE/$ARCH). 'exit' para salir."
              NSPAWN_EXTRA=(--bind="$OUT":/out); in_chroot /bin/bash -l || true ;;
  clean-sdl3) do_setup; rm -rf "$CHROOT/root/vpa-linux/build/sdl3"
              say "build/sdl3 borrado: el proximo build recompila la SDL3" ;;
  destroy)    [ -e "$CHROOT/.vpa-chroot-ready" ] || [ -d "$CHROOT/debootstrap" ] || \
                die "$CHROOT no parece un chroot de este script; no lo borro"
              say "Borrando $CHROOT"; rm -rf --one-file-system "$CHROOT" ;;
  -h|--help|help) sed -n '2,/^# =\{20,\}$/p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "orden desconocida: $1 (usa: build [ref] | setup | update | shell | clean-sdl3 | destroy)" ;;
esac
