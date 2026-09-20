#!/usr/bin/env python3
"""blur-check.py - comprueba que una zona de una captura no esta emborronada.

Fase 10 de WAYLAND.md (T10.5, HiDPI). input_test dibuja rayas verticales de
dos colores y captura la pantalla del compositor con 'grim -t ppm'. Si la
imagen se ha escalado con vecino mas proximo, en la zona solo hay esos DOS
colores; si alguien (SDL o el compositor) la ha interpolado, aparecen
intermedios. Sale con 0 si hay como mucho dos colores, con 1 si hay mas.
Con un sexto argumento N comprueba ademas que las rayas miden N pixeles
fisicos exactos (el color cambia cada N columnas): asi se ve si la imagen se
ha dibujado a la resolucion fisica o a la logica y luego ampliada.

Uso: blur-check.py CAPTURA.ppm X0 Y0 X1 Y1 [N]  (pixeles fisicos, X1/Y1 fuera)
"""
import sys

def main():
    path, x0, y0, x1, y1 = sys.argv[1], *map(int, sys.argv[2:6])
    data = open(path, "rb").read()
    # cabecera P6: magia, ancho, alto, maximo, separados por blancos
    fields, pos = [], 0
    while len(fields) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        end = pos
        while not data[end:end + 1].isspace():
            end += 1
        fields.append(data[pos:end]); pos = end
    pos += 1
    if fields[0] != b"P6" or fields[3] != b"255":
        sys.exit("blur-check: not a P6/255 PPM")
    w, h = int(fields[1]), int(fields[2])
    if x1 > w or y1 > h:
        sys.exit("blur-check: region outside the %dx%d capture" % (w, h))
    colours = set()
    for y in range(y0, y1):
        row = data[pos + (y * w + x0) * 3: pos + (y * w + x1) * 3]
        colours.update(row[i:i + 3] for i in range(0, len(row), 3))
    print("blur-check: %dx%d capture, %d colours in the region" % (w, h, len(colours)))
    if len(colours) > 2:
        sys.exit(1)
    if len(sys.argv) > 6:
        n = int(sys.argv[6])
        for y in range(y0, y1):
            row = data[pos + (y * w + x0) * 3: pos + (y * w + x1) * 3]
            px = [row[i:i + 3] for i in range(0, len(row), 3)]
            for x in range(len(px) - n):
                if (px[x] == px[x + n]) or (x % n and px[x] != px[x - 1]):
                    print("blur-check: stripes are not %d px wide at (%d,%d)" % (n, x0 + x, y))
                    sys.exit(1)
    sys.exit(0)

main()
