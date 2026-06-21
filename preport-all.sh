#!/usr/bin/env bash
#
# preport-all.sh - Aplica preport.py a TODO el build vivo, con copias .orig y resumen.
#
# Hace la pasada MECANICA (EOL, {$C}, {$V-}) en todos los .PAS del build vivo de una vez.
# NO los hace compilar (las dependencias y el asm/Graph se portan despues), pero deja el
# trabajo mecanico hecho en todo el proyecto y un informe de que queda manual en cada uno.
#
# Omite el subsistema DPMI descartado (DPMI/DPMITEST/MEMTEST/SYSEXT) y la capa SVGA
# (que se reemplaza por ptcgraph en la Fase 2), y el directorio VPAMM completo.
#
# Uso (desde la raiz del proyecto, junto a preport.py):
#   bash preport-all.sh            # vista previa: solo informa, NO modifica
#   bash preport-all.sh --apply    # aplica in-place (crea .orig de cada fichero)
#
set -uo pipefail

DIRS="VPA UNIT CC VHLP"
REPORT="preport-report.txt"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

if [ ! -f preport.py ]; then
  echo "ERROR: no encuentro preport.py en el directorio actual."; exit 1
fi

skip() {  # ficheros a omitir (descartados o a reemplazar)
  case "$(basename "$1")" in
    DPMI.PAS|DPMITEST.PAS|MEMTEST.PAS|SYSEXT.PAS|SVGA.PAS) return 0 ;;
    *) return 1 ;;
  esac
}

total=0; clean=0; manual=0; skipped=0
: > "$REPORT"

for d in $DIRS; do
  [ -d "$d" ] || continue
  for f in "$d"/*.PAS; do
    [ -f "$f" ] || continue
    if skip "$f"; then echo "  omitido (descarte/reemplazo): $f"; skipped=$((skipped+1)); continue; fi
    total=$((total+1))
    if [ "$APPLY" -eq 1 ]; then
      python3 preport.py "$f" --in-place >>"$REPORT" 2>&1
    else
      python3 preport.py "$f" >/dev/null 2>>"$REPORT"
    fi
    code=$?
    if [ "$code" -eq 0 ]; then clean=$((clean+1)); else manual=$((manual+1)); fi
  done
done

echo ""
echo "========================================================"
if [ "$APPLY" -eq 1 ]; then
  echo " Pasada MECANICA aplicada (con copias .orig)."
else
  echo " VISTA PREVIA (no se modifico nada). Usa --apply para aplicar."
fi
echo "   Ficheros procesados:           $total"
echo "   - sin pendientes manuales:     $clean"
echo "   - con trabajo manual restante: $manual"
echo "   Omitidos (descarte/reemplazo): $skipped"
echo "   Informe detallado por fichero: $REPORT"
echo "========================================================"
