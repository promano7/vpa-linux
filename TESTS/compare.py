#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
compare.py - Comparador de volcados de framebuffer de VPA-Linux.

Tarea T0.7 de WAYLAND.md. Compara los ficheros .ppm (y sus .pal) producidos por
el volcado de ptcgraph (VPA_GRAPH_DUMP + Ctrl-F12) y dice si dos capturas son
identicas o en que se diferencian.

Sin dependencias externas: solo biblioteca estandar, como preport.py.

Uso
---
    compare.py REFERENCIA ACTUAL [opciones]

REFERENCIA y ACTUAL pueden ser dos ficheros .ppm o dos directorios. Si son
directorios, se emparejan los ficheros por nombre y se comparan uno a uno.

Opciones
--------
    --diff-dir DIR   escribe una imagen PNG de diferencias por cada par que no
                     coincida: la captura actual atenuada, con los pixeles
                     distintos marcados en magenta
    --tolerancia N   admite hasta N pixeles distintos sin considerarlo fallo
                     (por defecto 0: la equivalencia tiene que ser exacta)
    --quiet          solo imprime los fallos y el resumen final

Codigos de salida
-----------------
    0  todo coincide dentro de la tolerancia
    1  hay diferencias
    2  error de uso o de lectura
"""

import os
import struct
import sys
import zlib

MAGENTA = (255, 0, 255)


# ---------------------------------------------------------------- lectura PPM

class PPMError(Exception):
    pass


def leer_ppm(ruta):
    """Devuelve (ancho, alto, bytes RGB) de un PPM binario P6.

    Acepta comentarios y espaciado arbitrario en la cabecera, que es lo que
    permite el formato, aunque nuestro volcado genere siempre la forma minima.
    """
    with open(ruta, 'rb') as f:
        datos = f.read()

    if not datos.startswith(b'P6'):
        raise PPMError('no es un PPM binario (P6): %s' % ruta)

    campos = []
    i = 2
    while len(campos) < 3:
        while i < len(datos) and datos[i:i + 1].isspace():
            i += 1
        if datos[i:i + 1] == b'#':                 # comentario hasta fin de linea
            while i < len(datos) and datos[i:i + 1] != b'\n':
                i += 1
            continue
        j = i
        while j < len(datos) and not datos[j:j + 1].isspace():
            j += 1
        if j == i:
            raise PPMError('cabecera truncada: %s' % ruta)
        campos.append(int(datos[i:j]))
        i = j
    i += 1                                          # el unico espacio tras maxval

    ancho, alto, maxval = campos
    if maxval != 255:
        raise PPMError('maxval %d no soportado (se espera 255): %s'
                       % (maxval, ruta))

    esperado = ancho * alto * 3
    px = datos[i:i + esperado]
    if len(px) != esperado:
        raise PPMError('faltan datos: %d bytes de %d esperados en %s'
                       % (len(px), esperado, ruta))
    return ancho, alto, px


def leer_pal(ruta):
    """Devuelve los 768 bytes de la paleta, o None si no hay fichero .pal."""
    pal = os.path.splitext(ruta)[0] + '.pal'
    if not os.path.exists(pal):
        return None
    with open(pal, 'rb') as f:
        datos = f.read()
    if len(datos) != 768:
        raise PPMError('paleta de %d bytes, se esperaban 768: %s'
                       % (len(datos), pal))
    return datos


# ------------------------------------------------------------- escritura PNG

def escribir_png(ruta, ancho, alto, rgb):
    """Escribe un PNG RGB de 8 bits sin filtros. Solo para las imagenes de
    diferencias: no hace falta que sea optimo, hace falta que sea legible."""
    crudo = b''.join(b'\x00' + rgb[y * ancho * 3:(y + 1) * ancho * 3]
                     for y in range(alto))

    def bloque(tipo, contenido):
        return (struct.pack('>I', len(contenido)) + tipo + contenido +
                struct.pack('>I', zlib.crc32(tipo + contenido)))

    png = (b'\x89PNG\r\n\x1a\n' +
           bloque(b'IHDR', struct.pack('>IIBBBBB', ancho, alto, 8, 2, 0, 0, 0)) +
           bloque(b'IDAT', zlib.compress(crudo, 6)) +
           bloque(b'IEND', b''))
    with open(ruta, 'wb') as f:
        f.write(png)


# -------------------------------------------------------------- comparacion

class Resultado(object):
    def __init__(self, nombre):
        self.nombre = nombre
        self.error = None
        self.distintos = 0
        self.total = 0
        self.caja = None          # (x0, y0, x1, y1) de los pixeles distintos
        self.primero = None       # (x, y, rgb_ref, rgb_act)
        self.delta_max = 0
        self.paleta_distinta = False
        self.paleta_entradas = []

    @property
    def identicos(self):
        return self.error is None and self.distintos == 0


def comparar(ref, act, nombre, dir_diff=None):
    r = Resultado(nombre)
    try:
        w1, h1, p1 = leer_ppm(ref)
        w2, h2, p2 = leer_ppm(act)
    except (PPMError, IOError) as e:
        r.error = str(e)
        return r

    if (w1, h1) != (w2, h2):
        r.error = 'dimensiones distintas: %dx%d frente a %dx%d' % (w1, h1, w2, h2)
        return r

    r.total = w1 * h1

    # paleta: una diferencia solo de paleta explica un cambio de color sin
    # cambio de dibujo, y conviene distinguirlo
    try:
        pal1, pal2 = leer_pal(ref), leer_pal(act)
        if pal1 is not None and pal2 is not None and pal1 != pal2:
            r.paleta_distinta = True
            r.paleta_entradas = [c for c in range(256)
                                 if pal1[c * 3:c * 3 + 3] != pal2[c * 3:c * 3 + 3]]
    except PPMError as e:
        r.error = str(e)
        return r

    if p1 == p2:
        return r                                    # camino rapido: identicos

    x0, y0, x1, y1 = w1, h1, -1, -1
    marcas = bytearray(p2) if dir_diff else None

    for y in range(h1):
        base = y * w1 * 3
        fila1 = p1[base:base + w1 * 3]
        fila2 = p2[base:base + w1 * 3]
        if fila1 == fila2:
            continue
        for x in range(w1):
            o = x * 3
            a = fila1[o:o + 3]
            b = fila2[o:o + 3]
            if a == b:
                continue
            r.distintos += 1
            d = max(abs(a[k] - b[k]) for k in range(3))
            if d > r.delta_max:
                r.delta_max = d
            if r.primero is None:
                r.primero = (x, y, tuple(a), tuple(b))
            if x < x0: x0 = x
            if y < y0: y0 = y
            if x > x1: x1 = x
            if y > y1: y1 = y
            if marcas is not None:
                m = base + o
                marcas[m:m + 3] = bytes(MAGENTA)

    if r.distintos:
        r.caja = (x0, y0, x1, y1)

    if dir_diff and r.distintos:
        # atenuar lo que coincide para que las marcas destaquen
        for i in range(0, len(marcas), 3):
            if bytes(marcas[i:i + 3]) != bytes(MAGENTA):
                marcas[i] = marcas[i] // 3
                marcas[i + 1] = marcas[i + 1] // 3
                marcas[i + 2] = marcas[i + 2] // 3
        salida = os.path.join(dir_diff, os.path.splitext(nombre)[0] + '-diff.png')
        escribir_png(salida, w1, h1, bytes(marcas))
        r.png = salida

    return r


# --------------------------------------------------------------------- salida

def informe(r, tolerancia, quiet):
    if r.error:
        print('  FALLO   %s: %s' % (r.nombre, r.error))
        return False

    ok = r.distintos <= tolerancia

    if r.identicos:
        if not quiet:
            print('  ok      %s (%d pixeles identicos)' % (r.nombre, r.total))
        return True

    etiqueta = 'TOLERADO' if ok else 'DIFIERE '
    pct = 100.0 * r.distintos / r.total
    print('  %s %s: %d de %d pixeles (%.4f %%)'
          % (etiqueta, r.nombre, r.distintos, r.total, pct))
    x0, y0, x1, y1 = r.caja
    print('            caja de cambios : (%d,%d)-(%d,%d)' % (x0, y0, x1, y1))
    x, y, a, b = r.primero
    print('            primer distinto : (%d,%d) ref=%s act=%s' % (x, y, a, b))
    print('            delta maximo    : %d por canal' % r.delta_max)
    if r.paleta_distinta:
        entradas = r.paleta_entradas
        muestra = ', '.join(str(c) for c in entradas[:12])
        if len(entradas) > 12:
            muestra += ', ...'
        print('            PALETA distinta : %d entradas (%s)'
              % (len(entradas), muestra))
        print('            -> puede ser un problema de paleta, no de dibujo')
    if getattr(r, 'png', None):
        print('            imagen de diff  : %s' % r.png)
    return ok


def main(argv):
    args = [a for a in argv[1:] if not a.startswith('--')]
    opts = [a for a in argv[1:] if a.startswith('--')]

    dir_diff = None
    tolerancia = 0
    quiet = False
    i = 0
    while i < len(opts):
        o = opts[i]
        if o == '--diff-dir':
            # el valor viaja en args porque no empieza por --
            if not args:
                print('error: --diff-dir necesita un directorio', file=sys.stderr)
                return 2
            dir_diff = args.pop()
        elif o.startswith('--diff-dir='):
            dir_diff = o.split('=', 1)[1]
        elif o.startswith('--tolerancia='):
            tolerancia = int(o.split('=', 1)[1])
        elif o == '--quiet':
            quiet = True
        else:
            print('error: opcion desconocida %s' % o, file=sys.stderr)
            return 2
        i += 1

    if len(args) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    ref, act = args
    if dir_diff:
        os.makedirs(dir_diff, exist_ok=True)

    if os.path.isdir(ref) != os.path.isdir(act):
        print('error: compara dos ficheros o dos directorios, no una mezcla',
              file=sys.stderr)
        return 2

    if os.path.isdir(ref):
        nombres = sorted(n for n in os.listdir(ref) if n.lower().endswith('.ppm'))
        if not nombres:
            print('error: no hay ficheros .ppm en %s' % ref, file=sys.stderr)
            return 2
        pares = []
        for n in nombres:
            destino = os.path.join(act, n)
            if not os.path.exists(destino):
                print('  FALLO   %s: no existe en %s' % (n, act))
                pares.append(None)
            else:
                pares.append((os.path.join(ref, n), destino, n))
    else:
        pares = [(ref, act, os.path.basename(act))]

    print('Comparando %d captura(s). Tolerancia: %d pixeles.'
          % (len([p for p in pares if p]), tolerancia))
    print()

    fallos = 0
    identicas = 0
    for par in pares:
        if par is None:
            fallos += 1
            continue
        r = comparar(par[0], par[1], par[2], dir_diff)
        if not informe(r, tolerancia, quiet):
            fallos += 1
        elif r.identicos:
            identicas += 1

    total = len(pares)
    print()
    print('Resumen: %d de %d identicas, %d fallo(s).' % (identicas, total, fallos))
    return 1 if fallos else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
