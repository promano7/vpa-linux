#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
swapgraph.py - Fase 2: sustituye 'Graph' -> 'ptcgraph' (y 'Crt' -> 'ptccrt') SOLO
dentro de las clausulas 'uses' (todas: interface e implementation), preservando
los bytes/encoding originales. No toca 'Graph'/'Crt' que aparezcan como
identificadores fuera de un 'uses'.

Uso:
  python3 swapgraph.py ARCHIVO.PAS              # vista previa por stdout
  python3 swapgraph.py ARCHIVO.PAS --in-place   # aplica (crea copia .preswap)
"""
import sys, re

def swap(text):
    n = 0
    def repl(m):
        nonlocal n
        clause = m.group(0)
        new = re.sub(r'(?i)\bgraph\b', 'ptcgraph', clause)
        new = re.sub(r'(?i)\bcrt\b', 'ptccrt', new)
        if new != clause:
            n += 1
        return new
    # cada clausula 'uses ... ;' (case-insensitive, puede ocupar varias lineas)
    return re.sub(r'(?is)\buses\b.*?;', repl, text), n

def main():
    if len(sys.argv) < 2:
        sys.stderr.write('uso: swapgraph.py ARCHIVO.PAS [--in-place]\n'); return 1
    path = sys.argv[1]
    data = open(path, 'rb').read().decode('latin-1')
    res, n = swap(data)
    if '--in-place' in sys.argv:
        open(path + '.preswap', 'wb').write(data.encode('latin-1'))
        open(path, 'wb').write(res.encode('latin-1'))
        sys.stderr.write('swapgraph: %s -> %d clausulas uses modificadas (.preswap guardado)\n' % (path, n))
    else:
        sys.stdout.buffer.write(res.encode('latin-1'))
        sys.stderr.write('swapgraph: %d clausulas uses afectadas (vista previa)\n' % n)
    return 0

if __name__ == '__main__':
    sys.exit(main())
