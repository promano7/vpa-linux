#!/usr/bin/env python3
"""pixel-check.py - comprueba el color de un pixel de una captura.

Fase 10 de WAYLAND.md (T10.2, bandas del letterbox). input_test pone un fondo
de color chillon en el compositor (swaybg), ensancha la ventana para que haya
bandas y captura la pantalla con 'grim -t ppm'. Si las bandas son opacas, el
pixel es negro; si la consola las borra con alfa 0, el compositor mezcla y se
ve el fondo (visto en KWin: el escritorio asomaba por las bandas).
Sale con 0 si el pixel tiene el color pedido, con 1 si no (y dice cual tiene).

Uso: pixel-check.py CAPTURA.ppm X Y RRGGBB   (pixeles fisicos)
"""
import sys

def main():
    path, x, y, want = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4].lower()
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
        sys.exit("pixel-check.py: %s no es un PPM P6 de 8 bits" % path)
    w, h = int(fields[1]), int(fields[2])
    if not (0 <= x < w and 0 <= y < h):
        sys.exit("pixel-check.py: (%d,%d) fuera de la captura de %dx%d" % (x, y, w, h))
    o = pos + (y * w + x) * 3
    got = "%02x%02x%02x" % (data[o], data[o + 1], data[o + 2])
    if got != want:
        print("pixel-check.py: (%d,%d) es %s, se esperaba %s" % (x, y, got, want))
        sys.exit(1)

main()
