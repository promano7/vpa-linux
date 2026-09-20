#!/usr/bin/env python3
"""T7.4 (desechable): pixeles distintos entre dos .ppm del guion de lineas,
desglosados por bloque del guion.   uso: t74_regiones.py ref.ppm act.ppm"""
import sys, re
def ppm(p):
    d = open(p, 'rb').read(); m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+(\d+)\s', d); return d[m.end():]
a, b = ppm(sys.argv[1]), ppm(sys.argv[2])
reg = {'1 abanico solido fino': (0, 0, 245, 245), '2 estilos x grosor': (245, 0, 640, 250),
       '3 XOR': (0, 250, 335, 480), '4 viewport/recorte': (335, 250, 640, 480)}
tot = 0
for n, (x1, y1, x2, y2) in reg.items():
    c = sum(1 for y in range(y1, y2) for x in range(x1, x2)
            if a[(y*640+x)*3:(y*640+x)*3+3] != b[(y*640+x)*3:(y*640+x)*3+3])
    tot += c; print(f"  {n:24s} {c:6d}")
print(f"  {'TOTAL':24s} {tot:6d}")
