#!/bin/bash
# Construye el paquete distribuible de VPA-Linux para arm64 en un chroot de
# Debian 12 (bookworm). Toda la logica y la ayuda estan en
# vpa-chroot-bookworm.sh:   tools/vpa-chroot-bookworm-arm64.sh help
exec "$(dirname "$(readlink -f "$0")")/vpa-chroot-bookworm.sh" arm64 "$@"
