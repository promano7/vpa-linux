#!/bin/sh
# Fase 7 (desechable): reconstruye los prototipos y repite TODAS las medidas
# que cita docs/adr-001-motor-wayland.md. Desde la raiz del repositorio:
#     TESTS/fase7/medir.sh
# Necesita: fpc 3.2.2, libSDL3 >= 3.4.4 (con su enlace libSDL3.so; si no esta
# en una ruta estandar: SDL3_LIBDIR=/usr/local/lib), weston, xvfb-run, python3.
set -e
B=build/fase7; U=$B/unitsB; T=$B/t74
L=${SDL3_LIBDIR:+-Fl$SDL3_LIBDIR}
q() { "$@" > $B/fpc.log 2>&1 || { cat $B/fpc.log; exit 1; }; }
rm -rf $B; mkdir -p $U $B/o72 $B/x11 $B/viaB/pres $T/ref $T/a1 $T/a2 $T/u0 $T/u1 $T/u2
make -s direct-units > /dev/null

echo "== T7.2  SDL3 minimo en Wayland (sin DISPLAY)"
q fpc -FuVENDOR/sdl3 -FiVENDOR/sdl3 -FU$B/o72 -FE$B/o72 $L TESTS/fase7/t72_sdl3min.lpr
TESTS/fase7/con-weston.sh $B/o72/t72_sdl3min 2>/dev/null
SDL_RENDER_DRIVER=software TESTS/fase7/con-weston.sh $B/o72/t72_sdl3min 2>/dev/null | grep -E "renderizador|distintos"

echo "== T7.3  via B: ptcgraph sobre la consola SDL3, contra ptcgraph sobre X11"
F="-O2 -Cg -dPTC_SDL3 -FiVENDOR/ptc -FiVENDOR/ptc/core -FiVENDOR/ptc/sdl -FuVENDOR/ptc -FuVENDOR/sdl3 -FiVENDOR/sdl3 $L"
q fpc $F -FU$U VENDOR/ptc/ptc.pp
q fpc $F -FU$U VENDOR/ptc/ptcwrapper.pp
q fpc -O2 -Cg -FiVENDOR -Fu$U -FU$U VENDOR/ptcgraph.pp
q fpc -MOBJFPC -dDIRECT -FiGRAPH -Fu$U -FU$U $L -o$B/scene_viaB TESTS/x11/scene_test.lpr
q fpc -MOBJFPC -dDIRECT -FiGRAPH -Fubuild/directunits -Fubuild/ptcunits -FU$B/x11 -o$B/scene_x11 TESTS/x11/scene_test.lpr
echo "   bibliotecas de scene_viaB: $(ldd $B/scene_viaB | awk '{print $1}' | grep -v 'vdso\|ld-linux' | tr '\n' ' ')"
xvfb-run -a -s "-screen 0 1024x768x24" $B/scene_x11 - $B/x11/scene > $B/x11/log.txt 2>&1
VPA_SCENE_PAUSE_MS=200 VPA_PROTO_PRESENTED=$PWD/$B/viaB/pres/f \
  TESTS/fase7/con-weston.sh $B/scene_viaB - $B/viaB/scene > $B/viaB/log.txt 2>&1
grep '^scene_test:' $B/x11/log.txt $B/viaB/log.txt
n=0; for f in $B/x11/scene0*; do cmp -s $f $B/viaB/$(basename $f) && n=$((n+1)); done
echo "   volcados (.ppm y .pal) identicos entre X11 y Wayland: $n de 10"
python3 TESTS/fase7/presentado.py $B/viaB $B/viaB/pres
echo "   lineas de la consola SDL3: $(cat VENDOR/ptc/sdl/*.inc | wc -l)"

echo "== T7.4  via A: Line + SetLineStyle + XORPut, contra ptcgraph"
q fpc -dREFERENCIA -FiTESTS/fase7 -Fubuild/directunits -Fubuild/ptcunits -FU$T/u0 -o$T/ref_bin TESTS/fase7/t74_line.lpr
q fpc -dINTENTO1 -FiTESTS/fase7 -FuTESTS/fase7 -FU$T/u1 -o$T/a1_bin TESTS/fase7/t74_line.lpr
q fpc -FiTESTS/fase7 -FuTESTS/fase7 -FU$T/u2 -o$T/a2_bin TESTS/fase7/t74_line.lpr
xvfb-run -a $T/ref_bin $T/ref/line > /dev/null
for i in 1 2; do
  $T/a${i}_bin $T/a$i/line $T/ref/line0001.pal
  echo "   intento $i:"; python3 TESTS/fase7/t74_regiones.py $T/ref/line0001.ppm $T/a$i/line0001.ppm
done
