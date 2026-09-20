#!/bin/bash
#
# run.sh - Comparacion visual automatizada de los backends graficos.
#
# Tareas T11.1 y T11.2 de WAYLAND.md. Captura el catalogo de escenas de
# docs/reference-scenes.md con cada backend (TESTS/capture.sh), compara cada
# captura con las imagenes doradas (TESTS/compare.py) y deja un informe con los
# pixeles distintos, el mapa de diferencias y el veredicto.
#
# No dibuja ni compara nada por su cuenta: es el director de capture.sh y
# compare.py, para que lo que se mide aqui sea lo mismo que se midio al dorar.
#
# Uso
# ---
#     TESTS/visual/run.sh [ESCENA...]
#
# Sin ESCENA se pasan todas; con una o varias (E17 E21) solo esas.
#
# Variables de entorno
# --------------------
#     VPA_VISUAL_OUT       directorio de salida   (por defecto build/visual;
#                          se BORRA y se vuelve a crear en cada pasada)
#     VPA_VISUAL_BACKENDS  backends a probar      (por defecto "x11 wayland")
#     VPA_GOLDEN           directorio de doradas  (por defecto TESTS/golden)
# y las de TESTS/capture.sh (VPA_BIN, VPA_FIXTURE, VPA_RESOURCE...), que se le
# pasan tal cual. Para el backend wayland, si SDL3 no esta en una ruta
# estandar, LD_LIBRARY_PATH.
#
# Salida (en VPA_VISUAL_OUT)
# --------------------------
#     informe.md           el informe: procedencia, una fila por escena y
#                          backend, veredicto
#     x11/  wayland/       los volcados .ppm/.pal y el log de VPA por escena
#     x11.txt wayland.txt  la salida completa de compare.py
#     diff-x11/ diff-wayland/
#                          el mapa de diferencias (PNG: la captura atenuada con
#                          los pixeles distintos en magenta) de cada escena que
#                          no coincida; vacios si todo coincide
#
# Umbral (T11.3): CERO. El plugin Wayland pinta con el mismo ptcgraph que el
# X11 (via B), asi que no hay ninguna diferencia que tolerar; las unicas cajas
# admitidas son las de TESTS/excepciones.txt, que esta vacio. Aqui no se pasa
# --tolerancia a compare.py y no hay opcion para pasarla.
#
# Codigos de salida
# -----------------
#     0  todas las escenas de todos los backends son identicas a las doradas
#     1  alguna difiere o no se ha podido capturar
#     2  error de uso o de entorno (faltan las doradas, no son las de
#        SHA256SUMS, falta el binario...)
#

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${VPA_VISUAL_OUT:-$ROOT/build/visual}"
BACKENDS="${VPA_VISUAL_BACKENDS:-x11 wayland}"
GOLDEN="${VPA_GOLDEN:-$ROOT/TESTS/golden}"
SCENES="$*"

die() { echo "run.sh: $*" >&2; exit 2; }

for b in $BACKENDS; do
  case "$b" in
    x11|wayland) ;;
    *) die "backend desconocido: '$b' (x11 o wayland)" ;;
  esac
done
command -v python3 >/dev/null 2>&1 || die "falta python3"
[ -f "$GOLDEN/SHA256SUMS" ] || die "no hay $GOLDEN/SHA256SUMS"

# Las doradas tienen que ser las que el repositorio dice que son. Comparar
# contra unas doradas cualesquiera daria un veredicto que no significa nada.
# (Con escenas sueltas solo se comprueban las de esas escenas.)
if [ -n "$SCENES" ]; then
  pattern="$(printf ' %s-\n' $SCENES)"
  sums="$(grep -F "$pattern" "$GOLDEN/SHA256SUMS")"
else
  sums="$(cat "$GOLDEN/SHA256SUMS")"
fi
[ -n "$sums" ] || die "ninguna de las escenas pedidas ($SCENES) esta en $GOLDEN/SHA256SUMS"
( cd "$GOLDEN" && sha256sum -c --quiet - <<< "$sums" ) >&2 ||
  die "las doradas de $GOLDEN faltan o no son las de SHA256SUMS (ver TESTS/golden/README.md)"

# Referencia de la comparacion: enlaces a las doradas de las escenas pedidas,
# porque compare.py empareja por nombre todo lo que haya en el directorio de
# referencia y una escena no capturada seria un fallo.
rm -rf "$OUT"
mkdir -p "$OUT/ref" || die "no se puede crear $OUT"
while read -r _ name; do
  ln -s "$GOLDEN/$name" "$OUT/ref/$name"
done <<< "$sums"

rc=0
for b in $BACKENDS; do
  echo "== $b: captura"
  if ! VPA_CAPTURE="$b" "$ROOT/TESTS/capture.sh" "$OUT/$b" $SCENES; then
    echo "== $b: la captura ha fallado" >&2
    rc=1
  fi
  echo "== $b: comparacion con las doradas"
  python3 "$ROOT/TESTS/compare.py" "$OUT/ref" "$OUT/$b" --diff-dir="$OUT/diff-$b" \
    > "$OUT/$b.txt" 2>&1
  case $? in
    0) ;;
    1) rc=1 ;;
    *) cat "$OUT/$b.txt" >&2; die "compare.py ha fallado con el backend $b" ;;
  esac
  tail -1 "$OUT/$b.txt"
done

# --- informe -------------------------------------------------------------------

commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
git -C "$ROOT" diff --quiet HEAD 2>/dev/null || commit="$commit (con cambios sin confirmar)"
fpcver="$(fpc -iV 2>/dev/null || echo '?')"

OUT="$OUT" BACKENDS="$BACKENDS" COMMIT="$commit" FPCVER="$fpcver" RC="$rc" \
python3 - <<'EOF' > "$OUT/informe.md"
import os, re, time

out = os.environ['OUT']
backends = os.environ['BACKENDS'].split()

# Una fila de compare.py por escena:
#   "  ok      E01-0001.ppm (307200 pixeles identicos)"
#   "  DIFIERE E17-0001.ppm: 12 de 307200 pixeles (0.0039 %)"
#   "            caja de cambios : (10,20)-(30,40)"
#   "  FALLO   E03-0001.ppm: no existe en ..."
res = {}
for b in backends:
    cur = None
    for line in open(os.path.join(out, b + '.txt'), errors='replace'):
        m = re.match(r'\s+(ok|DIFIERE|TOLERADO|FALLO)\s+(E\d+\w*)-\d+\.ppm\b(.*)', line)
        if m:
            estado, esc, resto = m.groups()
            cur = res.setdefault(esc, {}).setdefault(b, {})
            cur['estado'] = estado
            n = re.match(r': (\d+) de \d+ pixeles', resto)
            cur['pix'] = int(n.group(1)) if n else 0
            cur['nota'] = resto.lstrip(': ').strip() if estado == 'FALLO' else ''
            continue
        m = re.match(r'\s+caja de cambios : (\S+)', line)
        if m and cur is not None:
            cur['caja'] = m.group(1)

print('# Comparacion visual de VPA-Linux (Fase 11 de WAYLAND.md)')
print()
print('| | |')
print('|---|---|')
print('| Fecha | %s |' % time.strftime('%Y-%m-%d %H:%M:%S %z'))
print('| Commit | `%s` |' % os.environ['COMMIT'])
print('| Free Pascal | %s |' % os.environ['FPCVER'])
print('| Backends | %s |' % ', '.join(backends))
print('| Referencia | `TESTS/golden/` (comprobada contra `SHA256SUMS`) |')
print('| Umbral | 0 pixeles; cajas admitidas: las de `TESTS/excepciones.txt` |')
print()
print('| Escena | ' + ' | '.join(backends) + ' |')
print('|---|' + '---|' * len(backends))
malas = 0
for esc in sorted(res):
    celdas = []
    for b in backends:
        r = res[esc].get(b)
        if r is None:
            celdas.append('sin comparar'); malas += 1
        elif r['estado'] == 'ok':
            celdas.append('identica')
        elif r['estado'] == 'FALLO':
            celdas.append('FALLO: ' + r['nota']); malas += 1
        else:
            celdas.append('**%d pixeles distintos**, caja %s, mapa: `diff-%s/`'
                          % (r['pix'], r.get('caja', '?'), b))
            malas += 1
    print('| %s | %s |' % (esc, ' | '.join(celdas)))
print()
total = len(res) * len(backends)
if os.environ['RC'] == '0' and malas == 0 and total > 0:
    print('**Veredicto: PASA.** %d de %d comparaciones identicas a las doradas.'
          % (total, total))
else:
    print('**Veredicto: FALLA.** %d de %d comparaciones no son identicas a las '
          'doradas (o alguna captura ha fallado). El detalle esta en `%s`.'
          % (malas, total, '`, `'.join(b + '.txt' for b in backends)))
EOF

echo
sed -n '/^| Escena/,$p' "$OUT/informe.md"
echo
echo "informe: $OUT/informe.md"
exit $rc
