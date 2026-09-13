#!/usr/bin/env python3
"""Inventario de la frontera grafica de VPA-Linux (WAYLAND.md, Fase 1).

Cuenta, excluyendo comentarios y literales de cadena, cuantas veces aparece
en VPA/, UNIT/, CC/ y VHLP/ cada simbolo que exportan las unidades que tocan
el sistema de ventanas: ptcgraph (VENDOR/graphh.inc + VENDOR/ptcgraph.pp),
ptccrt, ptcmouse y xfocus. Es la base de docs/vpagraph-api-inventory.md y la
herramienta de la revision cruzada T1.9.

Uso:
  TESTS/inventory.py            informe legible, agrupado por unidad
  TESTS/inventory.py --tsv      una linea por simbolo usado: unidad, simbolo,
                                clase, usos, ficheros, usos enlazados, ficheros
                                enlazados, usos enlazados seguidos de "(",
                                lista de ficheros, firma
  TESTS/inventory.py --unused   solo los simbolos exportados que VPA no usa
  TESTS/inventory.py --where SIMBOLO   fichero:linea de cada uso real

Un "uso" es una aparicion del identificador fuera de comentarios y cadenas,
que no va precedida de "." (acceso a campo), en un fichero que tiene la unidad
en su "uses" (o calificada como unidad.Simbolo). Un asterisco tras el nombre
de fichero marca los que el ejecutable VPA no enlaza hoy (CC/, TASKS, DETAILS,
las utilidades VHLPSHOW y VHLPMAKE). Los identificadores
que VPA redeclara localmente (parametros o campos con el mismo nombre) se
cuentan igual: el informe los marca con "!" para revisarlos a mano.

Sin dependencias fuera de la biblioteca estandar.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONSUMER_DIRS = ('VPA', 'UNIT', 'CC', 'VHLP')
CONSUMER_EXT = ('.pas', '.inc')

# Unidad -> ficheros cuya seccion "interface" define sus simbolos exportados.
# graphh.inc no tiene seccion interface: se lee entero.
FRONTIER = {
    'ptcgraph': ['VENDOR/graphh.inc', 'VENDOR/ptcgraph.pp'],
    'ptccrt':   ['VENDOR/ptccrt.pp'],
    'ptcmouse': ['VENDOR/ptcmouse.pp'],
    'xfocus':   ['UNIT/xfocus.pas'],
}

IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
KEYWORDS = {
    'and', 'array', 'begin', 'case', 'const', 'div', 'do', 'downto', 'else',
    'end', 'file', 'for', 'function', 'goto', 'if', 'implementation', 'in',
    'interface', 'label', 'mod', 'nil', 'not', 'of', 'or', 'packed',
    'procedure', 'program', 'record', 'repeat', 'set', 'shl', 'shr', 'string',
    'then', 'to', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with',
    'xor', 'absolute', 'external', 'forward', 'inline', 'assembler', 'asm',
    'object', 'constructor', 'destructor', 'virtual', 'private', 'public',
    'boolean', 'byte', 'word', 'integer', 'longint', 'shortint', 'smallint',
    'char', 'pointer', 'real', 'single', 'double', 'true', 'false',
}


def strip(src):
    """Sustituye comentarios y literales de cadena por espacios (conservando
    los saltos de linea, para que los numeros de linea sigan valiendo)."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '{':
            j = src.find('}', i)
            j = n if j < 0 else j + 1
            out.append(re.sub(r'[^\n]', ' ', src[i:j]))
            i = j
        elif c == '(' and src.startswith('(*', i):
            j = src.find('*)', i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r'[^\n]', ' ', src[i:j]))
            i = j
        elif c == '/' and src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif c == "'":
            j = i + 1
            while j < n and src[j] != '\n':
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            j = min(j + 1, n)
            out.append(' ' * (j - i))
            i = j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def read(path):
    with open(os.path.join(ROOT, path), 'rb') as f:
        return f.read().decode('latin-1')


def interface_section(text):
    m = re.search(r'^\s*interface\s*$', text, re.M | re.I)
    if not m:
        return text
    e = re.search(r'^\s*implementation\s*$', text, re.M | re.I)
    return text[m.end():e.start() if e else len(text)]


def exported_symbols(text):
    """Devuelve {nombre_minusculas: (Nombre, clase, firma)} de una seccion
    interface ya sin comentarios. Clases: proc, func, const, type, var, enum."""
    syms = {}
    section = None
    depth = 0          # anidamiento record/object ... end
    paren = 0          # parentesis abiertos (para no leer parametros)
    for raw in text.split('\n'):
        line = raw.strip()
        if not line:
            continue
        low = line.lower()
        m = re.match(r'(procedure|function)\s+([A-Za-z_]\w*)', line, re.I)
        if m and depth == 0:
            sig = re.sub(r'\s+', ' ', line.rstrip(';'))
            syms[m.group(2).lower()] = (m.group(2), m.group(1).lower(), sig)
            section = None
            continue
        if re.match(r'(const|type|var|threadvar)\b', low) and depth == 0:
            section = low.split()[0]
            rest = line[len(section):].strip()
            if not rest:
                continue
            line, low = rest, rest.lower()
        if section is None or depth < 0:
            continue
        # anidamiento de record/object
        toks = IDENT.findall(low)
        for t in toks:
            if t in ('record', 'object'):
                depth += 1
            elif t == 'end' and depth > 0:
                depth -= 1
        if depth > 0 and not re.match(r'[A-Za-z_]\w*\s*=\s*(packed\s+)?(record|object)', low):
            continue
        m = re.match(r'([A-Za-z_]\w*)\s*(=|:)', line)
        if m and paren == 0:
            name = m.group(1)
            if name.lower() in KEYWORDS:
                continue
            sig = re.sub(r'\s+', ' ', line.rstrip(';'))
            syms[name.lower()] = (name, section, sig)
            # miembros de enumeracion: Name = (a, b, c)
            em = re.match(r'[A-Za-z_]\w*\s*=\s*\(([^)]*)\)', line)
            if em and section == 'type':
                for member in IDENT.findall(em.group(1)):
                    syms[member.lower()] = (member, 'enum', 'miembro de ' + name)
        paren += line.count('(') - line.count(')')
        if paren < 0:
            paren = 0
    return syms


def frontier_symbols():
    result = {}
    for unit, files in FRONTIER.items():
        syms = {}
        for path in files:
            text = strip(read(path))
            if not path.endswith('.inc'):
                text = interface_section(text)
            syms.update(exported_symbols(text))
        result[unit] = syms
    return result


# Ficheros incluidos con {$I}: se cuentan como parte del fichero que los incluye.
INCLUDED_BY = {
    'VPA/RUSFONT.INC': 'VPA/SCREEN.PAS',
    'CC/HULLFUNC.INC': 'CC/HULLFUNC.PAS',
    'VPA/SWITCHES.INC': None,          # solo directivas de compilacion
}

# Bloques {$IFDEF X} ... {$ENDIF} que hoy NO se compilan (VPA/SWITCHES.INC):
# se descartan antes de calcular que unidades enlaza el ejecutable.
DEFINES_OFF = ('TASKS', 'VPACC', 'VPAMM')


def consumer_files():
    """Ficheros de los consumidores. Los de VHLP/ que tienen un homonimo en
    UNIT/ se omiten: vpa.cfg pone -FuUNIT antes de -FuVHLP, asi que el
    compilador siempre coge la copia de UNIT/ y la de VHLP/ es una copia
    antigua que no se enlaza (VHLPSHOW es ademas identico en ambos)."""
    unit_names = set(n.lower() for n in os.listdir(os.path.join(ROOT, 'UNIT')))
    for d in CONSUMER_DIRS:
        for name in sorted(os.listdir(os.path.join(ROOT, d))):
            if not name.lower().endswith(CONSUMER_EXT):
                continue
            if d == 'VHLP' and name.lower() in unit_names:
                continue
            path = os.path.join(d, name)
            if path in INCLUDED_BY:
                continue
            yield path


def source_with_includes(path):
    """Texto del fichero sin comentarios ni cadenas, con sus {$I} pegados al
    final (los numeros de linea de la parte incluida no son significativos)."""
    text = strip(read(path))
    for inc, owner in INCLUDED_BY.items():
        if owner == path:
            text += '\n' + strip(read(inc))
    return text


def linked_units():
    """Conjunto de ficheros que el ejecutable VPA enlaza realmente: cierre
    transitivo de los 'uses' desde VPA/VPA.PAS, ignorando los bloques
    condicionales desactivados en SWITCHES.INC."""
    units = {}
    for path in consumer_files():
        raw = read(path)
        for d in DEFINES_OFF:
            raw = re.sub(r'\{\$IFDEF\s+' + d + r'\}.*?\{\$(ENDIF|ELSE)[^}]*\}', '',
                         raw, flags=re.S | re.I)
        text = strip(raw)
        m = re.search(r'^\s*(unit|program)\s+([A-Za-z_]\w*)', text, re.M | re.I)
        name = m.group(2).lower() if m else os.path.splitext(os.path.basename(path))[0].lower()
        used = set()
        for um in re.finditer(r'\buses\b(.*?);', text, re.I | re.S):
            used |= set(u.lower() for u in IDENT.findall(um.group(1)))
        units.setdefault(name, (path, used))
    seen, todo = set(), ['vpa']
    while todo:
        u = todo.pop()
        if u in seen or u not in units:
            continue
        seen.add(u)
        todo.extend(units[u][1])
    return set(units[u][0] for u in seen)


def scan_consumers():
    """{fichero: [(linea, ident_minusculas, precedido_por_punto, seguido_de_paren,
                   en_declaracion)]}"""
    uses = {}
    hits = {}
    for path in consumer_files():
        text = source_with_includes(path)
        used = []
        for um in re.finditer(r'\buses\b(.*?);', text, re.I | re.S):
            used += [u.lower() for u in IDENT.findall(um.group(1))]
        uses[path] = used
        lst = []
        for lineno, line in enumerate(text.split('\n'), 1):
            for m in IDENT.finditer(line):
                before = line[:m.start()].rstrip()
                after = line[m.end():].lstrip()
                dotted = before.endswith('.')
                if dotted:
                    # "unidad.Simbolo" es un uso calificado, no un campo
                    qm = re.search(r'([A-Za-z_]\w*)\s*\.$', before)
                    if qm and qm.group(1).lower() in FRONTIER:
                        dotted = False
                        used.append(qm.group(1).lower())
                called = after.startswith('(')
                # "Nombre :" o "Nombre ," dentro de una lista de declaracion
                declared = bool(re.match(r'[:,]\s*', after)) and not called \
                    and not re.search(r'\b(if|while|until|then|else|do|and|or|not)\s*$', before, re.I) \
                    and not before.endswith((':=', '=', '(', '+', '-', '*', '/', ','))
                lst.append((lineno, m.group(0).lower(), dotted, called, declared))
        hits[path] = lst
    return uses, hits


def count(front, uses, hits):
    """{unidad: {sym: {fichero: [(linea, called, declared)]}}}"""
    table = {u: {s: {} for s in syms} for u, syms in front.items()}
    lookup = {}
    for u, syms in front.items():
        for s in syms:
            lookup.setdefault(s, []).append(u)
    own = set(f for files in FRONTIER.values() for f in files)
    for path, lst in hits.items():
        if path in own:
            continue
        for lineno, ident, dotted, called, declared in lst:
            if dotted or ident not in lookup:
                continue
            for u in lookup[ident]:
                if u not in uses[path]:
                    continue
                table[u][ident].setdefault(path, []).append((lineno, called, declared))
    return table


def main(argv):
    front = frontier_symbols()
    uses, hits = scan_consumers()
    table = count(front, uses, hits)
    linked = linked_units()

    def label(path):
        return os.path.basename(path) + ('' if path in linked else '*')

    if '--where' in argv:
        target = argv[argv.index('--where') + 1].lower()
        for u in front:
            if target in table[u]:
                for path, lines in sorted(table[u][target].items()):
                    for lineno, called, declared in lines:
                        mark = '!' if declared else (' ' if called else '.')
                        print('%s %s:%d' % (mark, path, lineno))
        return 0

    if '--tsv' in argv:
        for u, syms in front.items():
            for s, (name, kind, sig) in sorted(syms.items()):
                files = table[u][s]
                n = sum(len(v) for v in files.values())
                if n:
                    nl = sum(len(v) for p, v in files.items() if p in linked)
                    fl = sum(1 for p in files if p in linked)
                    nc = sum(1 for p, v in files.items() if p in linked for _, c, _ in v if c)
                    print('\t'.join([u, name, kind, str(n), str(len(files)), str(nl), str(fl), str(nc),
                                     ' '.join(label(p) for p in sorted(files)), sig]))
        return 0

    only_unused = '--unused' in argv
    print('Unidades de la frontera en los "uses" de los consumidores')
    print('(* = fichero que el ejecutable VPA no enlaza hoy):')
    for path, ul in uses.items():
        f = [u for u in ul if u in FRONTIER or u in ('ptc', 'ptcwrapper', 'x', 'xlib', 'xutil', 'xatom')]
        if f:
            print('  %-22s %s' % (path + ('' if path in linked else ' *'), ', '.join(sorted(set(f)))))
    for u, syms in front.items():
        print('\n== %s: %d simbolos exportados' % (u, len(syms)))
        for s, (name, kind, sig) in sorted(syms.items(), key=lambda kv: (-sum(len(v) for v in table[u][kv[0]].values()), kv[0])):
            files = table[u][s]
            n = sum(len(v) for v in files.values())
            if only_unused and n:
                continue
            if not only_unused and not n:
                continue
            flag = '!' if any(d for v in files.values() for _, _, d in v) else ' '
            nl = sum(len(v) for p, v in files.items() if p in linked)
            print('%s %-24s %-9s %5d usos (%4d enlazados) %2d fich  %s' % (
                flag, name, kind, n, nl, len(files),
                ' '.join(label(p) for p in sorted(files))))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
