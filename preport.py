#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
preport.py - Pre-portado mecanico de fuentes Pascal de VPA (DOS/BP7) a FPC/Linux.

Aplica SOLO los pasos mecanicos y seguros de la receta (README, seccion 6):
  1. Normaliza finales de linea CRLF/CR -> LF, PRESERVANDO el encoding original
     (trabaja a nivel de byte / latin-1; NO convierte a UTF-8, asi no rompe las
     tablas de caracteres DOS como UChr/LChr).
  2. Elimina la directiva Borland de segmento/overlay {$C ...} (MOVEABLE/PRELOAD/
     PERMANENT/...), que en Linux no significa nada y FPC rechaza.
  3. Inserta {$V-} tras la cabecera (unit/program) si aun no hay ninguna directiva $V.

Lo que NO toca (porque requiere criterio humano) lo DETECTA y AVISA con numero de
linea: ensamblador, interrupciones, E/S de puertos, acceso a memoria por hardware,
y clausulas 'uses' problematicas (Graph/Dos/WinAPI).

Uso:
  python3 preport.py ARCHIVO.PAS              # vista previa por stdout (no modifica)
  python3 preport.py ARCHIVO.PAS --in-place   # modifica el archivo (crea copia .orig)
  python3 preport.py ARCHIVO.PAS --out DEST   # escribe el resultado en DEST

Codigo de salida: 0 si el resultado queda "limpio"; 2 si quedan elementos que
requieren revision manual (asm, interrupciones, puertos, uses Graph/Dos/WinAPI).
"""

import sys
import os
import re
import argparse

# --- Transformaciones mecanicas -------------------------------------------------

def normalize_eol(text):
    return text.replace('\r\n', '\n').replace('\r', '\n')

# {$C MOVEABLE PRELOAD PERMANENT} y variantes: {$C <palabras>} (NO {$C+}/{$C-})
RE_CDIR = re.compile(r'\{\$C\s+[A-Za-z][^}]*\}', re.IGNORECASE)

def strip_segment_directives(text):
    new, n = RE_CDIR.subn('', text)
    return new, n

RE_VDIR = re.compile(r'\{\$V[+\-]\}', re.IGNORECASE)
RE_UNITHEAD = re.compile(r'^[ \t]*(unit|program)\b', re.IGNORECASE)

def insert_vminus(text):
    if RE_VDIR.search(text):
        return text, False  # ya hay una directiva $V, no tocamos
    lines = text.split('\n')
    for i, ln in enumerate(lines):
        if RE_UNITHEAD.match(ln):
            lines.insert(i + 1, '{$V-}')
            return '\n'.join(lines), True
    return text, False  # no se encontro cabecera (raro)

# --- Deteccion de cosas que necesitan trabajo manual ----------------------------

CHECKS = [
    ('ASM',        re.compile(r'^[ \t]*asm\b', re.IGNORECASE)),
    ('assembler',  re.compile(r'\bassembler\b', re.IGNORECASE)),
    ('INT/Intr',   re.compile(r'\bint[ \t]+[0-9a-f]+h\b|\bIntr[ \t]*\(|\bMsDos[ \t]*\(', re.IGNORECASE)),
    ('PuertoI/O',  re.compile(r'\bPort[WL]?\[', re.IGNORECASE)),
    ('Mem[]',      re.compile(r'\bMem[WL]?\[', re.IGNORECASE)),
    ('uses Graph', re.compile(r'\bgraph\b', re.IGNORECASE)),
    ('uses Dos',   re.compile(r'\bdos\b', re.IGNORECASE)),
    ('uses WinAPI',re.compile(r'\bwinapi\b', re.IGNORECASE)),
]
# 'absolute' suele ser aliasing portable: lo reportamos aparte como aviso suave.
RE_ABSOLUTE = re.compile(r'\babsolute\b', re.IGNORECASE)
# Limitamos uses-checks a lineas que sean realmente clausula 'uses'
RE_USESLINE = re.compile(r'^[ \t]*uses\b|,[ \t]*$', re.IGNORECASE)


def scan(text):
    findings = {}
    uses_context = False
    for i, ln in enumerate(text.split('\n'), start=1):
        stripped = ln.strip()
        # seguimiento simple de si estamos dentro de una clausula uses (multilinea)
        if re.match(r'^[ \t]*uses\b', ln, re.IGNORECASE):
            uses_context = True
        for name, rx in CHECKS:
            if name.startswith('uses '):
                # solo contar Graph/Dos/WinAPI dentro de una clausula uses
                if not uses_context:
                    continue
            if rx.search(ln):
                findings.setdefault(name, []).append(i)
        if uses_context and ';' in ln:
            uses_context = False
    abs_lines = [i for i, ln in enumerate(text.split('\n'), 1) if RE_ABSOLUTE.search(ln)]
    return findings, abs_lines


# --- Programa principal ---------------------------------------------------------

def process(path):
    raw = open(path, 'rb').read()
    text = raw.decode('latin-1')          # mapeo 1:1 byte<->char, nunca falla
    text = normalize_eol(text)
    text, n_c = strip_segment_directives(text)
    text, v_added = insert_vminus(text)
    return text, n_c, v_added


def main():
    ap = argparse.ArgumentParser(description='Pre-portado mecanico de fuentes VPA a FPC/Linux.')
    ap.add_argument('file', help='archivo .PAS de entrada')
    ap.add_argument('--in-place', action='store_true', help='modifica el archivo (crea .orig)')
    ap.add_argument('--out', metavar='DEST', help='escribe el resultado en DEST')
    args = ap.parse_args()

    if not os.path.isfile(args.file):
        sys.stderr.write('ERROR: no existe el archivo %s\n' % args.file)
        return 1

    text, n_c, v_added = process(args.file)
    findings, abs_lines = scan(text)

    # --- Informe (a stderr para no contaminar la salida del fuente) ---
    log = sys.stderr.write
    log('== preport: %s ==\n' % args.file)
    log('  - EOL normalizados a LF (encoding original preservado)\n')
    log('  - Directivas {$C ...} eliminadas: %d\n' % n_c)
    log('  - {$V-} %s\n' % ('insertado' if v_added else 'no necesario (ya habia $V o sin cabecera)'))

    manual = False
    if findings:
        log('\n  !! REVISION MANUAL NECESARIA:\n')
        for name in ['ASM', 'assembler', 'INT/Intr', 'PuertoI/O', 'Mem[]',
                     'uses Graph', 'uses Dos', 'uses WinAPI']:
            if name in findings:
                manual = True
                ls = findings[name]
                muestra = ', '.join(str(x) for x in ls[:8])
                extra = ' ...' if len(ls) > 8 else ''
                log('     %-12s x%-3d  lineas: %s%s\n' % (name, len(ls), muestra, extra))
    if abs_lines:
        log('\n  (i) %d usos de "absolute" (normalmente aliasing portable; revisar solo\n' % len(abs_lines))
        log('      los que aliaseen punteros/hardware). Lineas: %s%s\n'
            % (', '.join(str(x) for x in abs_lines[:8]), ' ...' if len(abs_lines) > 8 else ''))
    if not manual:
        log('\n  OK: no se detectaron asm/interrupciones/puertos/uses problematicos.\n')
        log('      Probablemente compile tras este pre-portado.\n')

    # --- Escritura del resultado ---
    data = text.encode('latin-1')
    if args.in_place:
        bak = args.file + '.orig'
        if not os.path.exists(bak):
            open(bak, 'wb').write(open(args.file, 'rb').read())
            log('\n  Copia de seguridad: %s\n' % bak)
        open(args.file, 'wb').write(data)
        log('  Escrito (in-place): %s\n' % args.file)
    elif args.out:
        open(args.out, 'wb').write(data)
        log('  Escrito: %s\n' % args.out)
    else:
        sys.stdout.buffer.write(data)  # vista previa por stdout
        log('\n  (vista previa por stdout; usa --in-place o --out para guardar)\n')

    return 2 if manual else 0


if __name__ == '__main__':
    sys.exit(main())
