#!/usr/bin/env python3
"""Fase 7 (desechable): para cada volcado sceneNNNN.ppm comprueba que entre
los cuadros que la consola SDL3 PRESENTO (XRGB en bruto, VPA_PROTO_PRESENTED)
hay uno identico pixel a pixel.   uso: presentado.py <dir volcados> <dir raw>"""
import sys, re, glob, hashlib
W, H = 640, 480
def ppm(path):
    d = open(path, 'rb').read()
    m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+(\d+)\s', d)
    return d[m.end():]
pres = {}
for f in sorted(glob.glob(sys.argv[2] + '/*.raw')):
    raw = open(f, 'rb').read()
    rgb = bytearray(W * H * 3)
    rgb[0::3] = raw[2::4]; rgb[1::3] = raw[1::4]; rgb[2::3] = raw[0::4]
    pres.setdefault(hashlib.sha256(rgb).hexdigest(), f)
print(f"{len(pres)} cuadros presentados distintos")
bad = 0
for f in sorted(glob.glob(sys.argv[1] + '/scene*.ppm')):
    h = hashlib.sha256(ppm(f)).hexdigest()
    if h in pres: print("  identico  ", f, "==", pres[h].split('/')[-1])
    else: print("  SIN PAREJA", f); bad += 1
sys.exit(1 if bad else 0)
