# VPA-Linux — Port nativo de VGA Planets Assistant a GNU/Linux

Reconstrucción del cliente **VPA (VGA Planets Assistant)** desde su código original
en Turbo/Borland Pascal para DOS hacia un binario **nativo de GNU/Linux**, compilado
con **Free Pascal (FPC)** y usando **`ptcgraph`/`ptccrt`** como capa gráfica en
sustitución de la BGI de Borland.

- **Código base de referencia:** VPA 3.67 (fuente de SourceForge).
- **Autor original:** Alex V. Ivlev (1993–96); mantenido posteriormente por otros.
- **Objetivo:** ejecutable Linux nativo, sin DOSBox ni dosemu.

> Estado del proyecto: **Fase 0 en curso**. Este documento se actualiza a medida
> que avanzamos. Ver la sección [Seguimiento](#seguimiento-del-progreso) al final.

> **Entorno verificado** (FPC 3.2.2 / Ubuntu 24.04): las units `ptcgraph`, `ptccrt`,
> `ptcmouse` y el backend `ptc` están disponibles (paquete `fp-units-gfx`), el toolchain
> compila y enlaza programas `ptcgraph`, y el binario resultante depende de **libX11**
> (será una app X11; en Wayland funciona vía XWayland). Detalles en
> [§5 Entorno de desarrollo](#5-entorno-de-desarrollo-verificado).

---

## 1. Análisis de licencia

> **Intención del proyecto (decisión del autor del port):** este port será **software
> libre, open source y gratuito** para toda la comunidad de VGA Planets, publicado en
> **GitHub**. Se acepta sin problema usar dependencias o referencias **GPL** si son la
> mejor opción técnica. El objetivo de licencia es, por tanto, una licencia libre
> **compatible con GPL** (previsiblemente la propia **GPL v2 o posterior**, que es
> compatible con el PDK y con `ptcgraph`/FPC). El requisito es simple: **dejar clara la
> licencia final y conservar todos los avisos de copyright** de cada autor (VPA original,
> PHOST/PDK, PCC2…) cuando el repo se haga público.

Antes de plantear redistribución conviene tener claro el estado real de la licencia,
porque **lo que aparece en la ficha de SourceForge no coincide con lo que dice el código**.

### Qué dice SourceForge
La ficha del proyecto declara **Mozilla Public License 1.1 (MPL 1.1)**.

### Qué dice realmente el código fuente
Tras revisar el árbol completo (versiones 3.63 y 3.67):

- **No existe ningún fichero `LICENSE` ni `COPYING`** en el paquete.
- **No hay cabeceras de licencia MPL** en los ficheros `.pas`.
- La cadena «Mozilla» o «MPL» **no aparece ni una sola vez** en todo el código.
- La etiqueta MPL 1.1 vive, por tanto, **solo como metadato del proyecto en SourceForge**,
  no como una concesión explícita escrita por los autores en los ficheros.

La autoría que sí está declarada en el código está **estratificada**:

| Parte | Autoría declarada | Notas |
|---|---|---|
| Núcleo de VPA | Alex V. Ivlev, «Copyright (c) 1993-96» | Base del programa |
| Mantenimiento posterior | Pantallas «Copyright (c) 1998» y «(c) 2003» | Mantenedores sucesivos |
| `CC/` (código PCC) y subsistema DPMI | Stefan Reuther | Sus términos remiten a `UNIT/DPMI.TXT` |
| Documentación empaquetada | Dave Killingsworth (Starbase), Unity… | Solo docs, no código |

### Qué significa en la práctica

**Para uso y port personal:** sin problema. El proyecto se ofrece públicamente como
software libre y modificar para uso propio un programa obtenido legalmente no plantea
conflicto. Se puede portar con tranquilidad.

**Para redistribución pública:** conviene un paso previo. La MPL 1.1 es perfectamente
apta para este objetivo (permite versiones modificadas; es un *copyleft débil por
fichero*; es compatible con el enlazado contra FPC/`ptcgraph`). El matiz es que aquí
la MPL 1.1 es **la intención declarada del mantenedor actual, no un grant escrito en
los ficheros por cada autor histórico**. Con varios autores y sin concesión explícita
en el código, lo limpio es:

1. **Contactar con el mantenedor actual** en SourceForge (`sfplanets`/`lastberserker`)
   y pedir que confirme la licencia, idealmente añadiendo un fichero `LICENSE` al repo.
2. Para las partes de **Stefan Reuther** (CC + DPMI), consultar `UNIT/DPMI.TXT` y, si hace
   falta, preguntarle directamente (sigue activo en la comunidad VGA Planets: PCC2, c2nu…).
   *Nota:* su código DPMI/CC está entre lo que probablemente se descarte en el port.
3. Conservar todos los avisos de copyright (Ivlev, Reuther y demás) en la versión derivada.

> **Nota MPL 1.1 + GPL:** la MPL 1.1 por sí sola se considera incompatible con la GPL.
> Esto **no afecta** a este port: FPC RTL y `ptcgraph` están bajo *LGPL modificada*
> (con excepción de enlazado), que no impone obligaciones tipo GPL. Solo sería relevante
> si en el futuro se incorporase código estrictamente GPL.

### Fuentes de referencia externas (PCC2 / PDK)

Para resolver el bloqueo de hull-functions (la API `EnumHullfuncs` que el núcleo
necesita y que en VPA vive en `CC/HULLFUNC.PAS`, con dependencias ausentes del
ecosistema PCC 1.x) se dispone del código de Stefan Reuther como **referencia**.
Son C/C++, **no contienen units Pascal** drop-in, pero documentan la lógica y el
formato de datos de hull-functions para una reimplementación autocontenida:

| Fuente | Contenido útil | Licencia |
|---|---|---|
| **PCC2** (`pcc-v2`, 2025) | `game/hullfunc.cc/.h` (lógica hull-functions en C++) | **Permisiva tipo BSD** ("PCC II License Terms": retener copyright, marcar modificaciones). © 2001-2024 Stefan Reuther & contributors. **No es GPL.** |
| **PDK** (`pdk`, 2010) | `hullfunc.c`, `pconfig.c` (`hullHasSpecial`, `HullDoesAlchemy`, `HullCanHyperwarp`…) | **GPL v2 o posterior.** © 1995-2000 Andrew Sterian, Thomas Voigt, Steffen Pietsch (+ M. van Rees, S. Reuther). |
| **cpluslib** (2025) | utilidades C++ (plantillas de contenedores) | **Dominio público.** |

**Implicación de licencia (a la luz de la intención del proyecto):** como el port será
libre y se acepta la **GPL**, **ambas fuentes son utilizables**. El **PDK** (`hullfunc.c`,
GPL v2+) puede usarse incluso como base de traducción directa; si se hace, esa porción
—y por contagio el resultado combinado— quedaría **GPL**, lo cual es coherente con el
objetivo (publicar bajo licencia libre compatible con GPL). La **PCC2** (permisiva tipo
BSD) sigue siendo la opción más flexible (compatible con cualquier licencia final) y suele
ser una referencia más legible/moderna en C++. En cualquier caso, se **conservan los avisos
de copyright** de los autores (PHOST/PDK: Sterian, Voigt, Pietsch, van Rees, Reuther; PCC2:
Reuther). Recordatorio práctico: la lógica de "qué casco tiene qué habilidad" la determinan
en gran parte los datos del juego (`hullfunc.txt`, `shiplist.txt`, `auxdata.hst`), cuyo
**formato son hechos** y no material protegible.

**Plan:** de momento la capa `Enum*` queda como *stub* vacío (la pantalla de habilidades de
nave saldrá vacía); se reimplementará en Pascal autocontenido tomando el PDK/PCC2 como
referencia, conservando los avisos de copyright correspondientes.

*Aviso: este análisis es informativo, no asesoramiento legal.*

---

## 2. Análisis del código base

Métricas reales medidas sobre el fuente **3.67** (solo ficheros `.pas`):

| Módulo | Ficheros | Líneas | Rol | Destino en el port |
|---|---:|---:|---|---|
| `VPA/` | 26 | 40.390 | Núcleo de la aplicación | **Migrar** |
| `VPAMM/` | 11 | 8.349 | «Modo mixto»: DPMI + VESA + kernel propio | **Descartar** |
| `UNIT/` | 11 | 3.293 | Capa de bajo nivel (ratón, teclado, DPMI…) | **Reescribir parcialmente** |
| `CC/` | 5 | 4.149 | Código PCC (mensajes de comandos PHost), opcional | Opcional (`$IFDEF VPACC`) |
| `VHLP/` | 3 | 324 | Sistema de ayuda | Migrar (sencillo) |
| **Total** | **56** | **56.505** | | |

### Dónde se concentra la dificultad

El dato clave del análisis: **el código dependiente de DOS está concentrado justo donde
menos molesta**.

| Dependencia | VPAMM (descartado) | UNIT (reescribir) | VPA núcleo | CC |
|---|---:|---:|---:|---:|
| Interrupciones (INT/Intr/MsDos) | 89 | 44 | 11 | 8 |
| Líneas de ensamblador en línea | 137 | 90 | 29 | 10 |
| `absolute`/`Mem`/`Port`/`Seg`/`Ofs` | 67 | 89 | 146 | 7 |

- Al **descartar VPAMM** eliminamos de golpe la mayor parte del asm y de las interrupciones.
- El grueso del resto está en `UNIT/MOUSE.PAS` y `UNIT/KEYBOARD.PAS`, que se reescriben **una vez**.
- El núcleo (40.000 líneas) queda casi limpio: 11 interrupciones y 29 líneas de asm en 10 ficheros.
- Ojo: muchos de los 146 `absolute` del núcleo son **aliasing de variables** (portable), no
  acceso a hardware. Hay que distinguirlos caso por caso.

### Lo que hay que sustituir sí o sí (binarios no recompilables)

| Fichero | Qué es | Sustituto |
|---|---|---|
| `VPA/SVGA.OBJ` | Driver SVGA BGI de U. von Bassewitz (256 colores VESA) | `ptcgraph` |
| `VPA/GREETS.ASM` | Ensamblador TASM 16 bits | Reescribir en Pascal o eliminar |
| `VPAMM/SANSFONT.OBJ`, `VPAMM/PROPFONT.OBJ` | Fuentes del modo mixto | N/A (VPAMM se descarta) |
| `*.bgi` (egavga) | Driver BGI de Borland (enlazado externo) | `ptcgraph` |

### Punto a favor decisivo

La aplicación dibuja **a través de la API estándar de BGI** (~2.400 llamadas tipo
`InitGraph`, `Line`, `OutTextXY`, `SetFillStyle`…). `ptcgraph` reimplementa esa API como
reemplazo casi *drop-in*. Además, el propio proyecto **ya abstrajo su capa gráfica una vez**
(`VPAMM/GRAPH.PAS` reimplementa la interfaz `Graph` sobre otro kernel), lo que demuestra
que el código solo depende de la *superficie* de la API, no de sus tripas.

> **Por qué `ptcgraph` y no SDL:** `ptcgraph` mantiene la API BGI, así que las ~2.400
> llamadas siguen funcionando casi sin tocar. `sdlgraph` está reportado como roto desde
> hace años por el propio equipo de FPC. SDL sigue siendo válido como *segunda fase* de
> modernización real, pero como vía de migración inicial obliga a reescribir todo a mano.

---

## 3. Estrategia general

1. **No portar todo.** Descartar el subsistema VPAMM/DPMI entero: resolvía un problema
   (límites de memoria de DOS) que en Linux nativo no existe.
2. **Preservar la capa gráfica vía `ptcgraph`** en lugar de reescribirla.
3. **Empezar por modo 640×480 / 16 colores**, que es lo más sólido en `ptcgraph`; evaluar
   256 colores después.
4. **Migración incremental** con git: cada fase es un conjunto de commits revisables y, a
   ser posible, un estado compilable.
5. **Objetivo de las primeras fases:** tener algo equivalente al original arrancando cuanto
   antes, y luego pulir.

---

## 4. Plan de migración paso a paso

Cada tarea se marca al completarse. Las fases buscan dejar el árbol en un estado
verificable al final de cada una.

### Fase 0 — Preparación del entorno
- [x] Instalar Free Pascal y verificar que incluye `ptcgraph`, `ptccrt`, `ptcmouse`, `ptc`. ✅ FPC **3.2.2**; units en el paquete `fp-units-gfx`. Toolchain compila y enlaza. *(Ver §5.)*
- [ ] Inicializar repositorio git e importar la 3.67 **intacta** como primer commit (base inmutable de referencia).
- [ ] Crear rama de trabajo `port-linux`.
- [ ] Añadir `.gitignore`, `.gitattributes` y `setup-env.sh` (entregables de esta fase, ya generados).
- [ ] Resolver/anotar el tema de licencia (contacto con mantenedor si se prevé distribuir).
- [ ] Convertir finales de línea CRLF→LF (lo gestiona `.gitattributes`) y documentar codificación de los textos.

### Fase 1 — Recorte y andamiaje de compilación
- [x] **VPAMM ya está desactivado** por defecto (`{.$DEFINE VPAMM}` en `switches.inc`): el build estándar de `vpa.pas` no lo incluye. No hay que tocar el núcleo para sacarlo.
- [ ] Excluir del build el directorio `VPAMM/` y las units DPMI de `UNIT/` (`DPMI`, `DPMITEST`, `MEMTEST`); opcionalmente moverlos a un `legacy/` para declutter.
- [x] `vpa.cfg` para FPC en modo `{$MODE TP}` con las rutas de units del proyecto + ptcgraph (ruta Arch verificada). *(Sustituye a `BPC.CFG`.)*
- [ ] Reescribir el `MAKEFILE` (era para Borland Make) como `Makefile` para FPC (se hará cuando valguemos el primer compilado de una unit hoja).
- [ ] Decidir sobre `VPACC` (hoy ON) y `TASKS` (hoy OFF): mantener o desactivar `VPACC` al principio para reducir superficie.
- [ ] **Limpieza global de directivas Borland** sin equivalente en Linux: `{$C MOVEABLE PRELOAD PERMANENT}` (atributos de segmento/overlay DOS), etc. — strip masivo.
- [ ] Primer compilado de tanteo (bottom-up, empezando por una unit hoja como `STRF`): **recoger la lista de errores reales**.

### Fase 2 — Capa gráfica (`ptcgraph`)
- [x] **Verificado: `ptcgraph` cubre el 100% de la API BGI que usa VPA** (probado compilando un programa con todas las llamadas: `Line`, `OutTextXY`, `GetImage`/`PutImage`, `Circle`, `Bar`, paletas, viewports…). Es prácticamente *drop-in*.
- [x] **`swapgraph.py`**: cambia `uses Graph`→`ptcgraph` (y `Crt`→`ptccrt`) en las cláusulas `uses` de los 22 ficheros afectados, preservando encoding. (VPA no usa `Crt`; sí `Dos` en 5 ficheros → Fase 4.)
- [ ] Aplicar `swapgraph.py` a los ficheros con `uses Graph`.
- [ ] **Reescribir la init de `VPA/VPAINIT.PAS`**: las ramas SVGA/CustomBGI/EGAVGA registran drivers BGI externos (`@svgaProc`, `@EGAVGADriverProc`, `@SmallFontProc`) que no enlazan en Linux. En ptcgraph `InstallUserDriver`/`RegisterBGIDriver` son no-ops; se sustituye todo el bloque por una llamada directa `InitGraph(gd,gm,'')` con un modo nativo (p.ej. `gd:=D8bit; gm:=m640x480` para 256 colores). Eliminar `SVGA.PAS`/`SVGA.OBJ`.
- [ ] Reescribir `GREETS.ASM` en Pascal o eliminarla.
- [ ] Portar la cadena del núcleo gráfico (`SCREEN`, `VPADATA`, `Global`…) hasta compilar.
- [ ] **Hito:** arrancar en modo gráfico y dibujar el mapa estelar.

### Fase 3 — Entrada: ratón y teclado
- [ ] Reescribir `UNIT/MOUSE.PAS` sobre `ptcmouse` (sondeo de eventos) en lugar de INT 33h + handler en asm.
- [ ] Reescribir `UNIT/KEYBOARD.PAS` sobre `ptccrt` (`ReadKey`, etc.).
- [ ] **Mapear los scancodes BIOS** que usa el bucle principal (`$3B00`=F1, `$3C00`=F2…) a los que devuelve `ptccrt`.
- [ ] **Hito:** navegar por el mapa y los menús con ratón y teclado.

### Fase 4 — Limpieza de bajo nivel (UNIT + núcleo)
- [ ] Eliminar `UNIT/DPMI.PAS`, `UNIT/DPMITEST.PAS`, `UNIT/MEMTEST.PAS`, `UNIT/SYSEXT.PAS` (eran del subsistema descartado; confirmar que nada vivo los usa).
- [ ] Revisar `UNIT/AUXF.PAS` y `UNIT/STRF.PAS`: sustituir asm por Pascal/intrínsecos de FPC.
- [ ] Tratar las ~11 interrupciones y ~29 líneas de asm del núcleo, fichero a fichero (hora del sistema, etc.).
- [ ] Clasificar los `absolute` del núcleo: *aliasing* (se queda) vs. acceso a hardware (se reescribe).

### Fase 5 — E/S de ficheros y portabilidad de datos *(crítica)*
- [ ] **Tamaños de tipos** *(parcialmente verificado en §5)*: en `{$MODE TP}` con FPC 3.2.2 x86_64, `Integer`=2, `Word`=2, `LongInt`=4 bytes (idénticos a BP7) y los `packed record` de enteros/bytes/chars serializan igual. **Dos trampas confirmadas:** `Pointer`=8 bytes (era 4) y `Real`=8 bytes (en BP7 el `Real` por defecto era de **6 bytes**). Hay que revisar si VPA guarda `Real` o punteros en disco.
- [ ] **Endianness:** validar lectura de los binarios (x86 era little-endian; vigilar si se compila para ARM).
- [ ] **Rutas:** manejar mayúsculas/minúsculas, separador `\`→`/` y nombres 8.3 de forma tolerante en Linux.
- [ ] Adaptar el manejo de errores de Borland (`ExitProc`, `ExitCode`, `ErrorAddr`, procedimientos `far`) al equivalente de FPC.

### Fase 6 — Primer binario nativo
- [ ] Iterar hasta lograr compilación limpia y un ejecutable que arranque.
- [ ] Probar con datos reales de una partida (RST/TRN).

### Fase 7 — Pruebas, empaquetado y (opcional) distribución
- [ ] Comparar comportamiento contra la versión DOS en DOSBox.
- [ ] Empaquetar (binario + ficheros de soporte: `vpa.hlp`, `vpa.msg`, recursos).
- [ ] Cerrar el tema de licencia si se publica.
- [ ] *(Opcional, fase posterior)* Evaluar 256 colores / resoluciones mayores, o un backend SDL para modernización real.
- [ ] **Eliminar la dependencia de `libXxf86dga`** recompilando `ptcgraph` sin DGA (comentar `ENABLE_X11_EXTENSION_XF86DGA1`/`_XF86DGA2` en `x11extensions.inc`), para que el binario distribuible no requiera una librería retirada de los repos.

---

## 5. Entorno de desarrollo (verificado)

Comprobado de forma efectiva sobre FPC **3.2.2** en Ubuntu 24.04 (x86_64).

### Software necesario
- **Free Pascal 3.2.2** (paquete `fpc`).
- **Units gráficas** (paquete `fp-units-gfx` → arrastra `fp-units-gfx-3.2.2`):
  `ptcgraph`, `ptccrt`, `ptcmouse` y el backend `ptc`. En Ubuntu se instalan en
  `/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/graph/`.
  En **Arch Linux** estas units vienen **dentro del propio paquete `fpc`** (no hay
  paquete aparte), en `/usr/lib/fpc/<versión>/units/x86_64-linux/graph/`; basta
  `sudo pacman -S --needed fpc libx11`.
- En tiempo de ejecución el binario depende de **libX11** (aplicación X11; en Wayland
  funciona vía XWayland, normalmente ya presente).
- **Dependencias de enlazado (X) y `gcc`:** al enlazar, FPC pasa `-lX11 -lXext -lXfixes
  -lXi -lXrandr -lXxf86dga -lXxf86vm`, y necesita los objetos `crt*.o` de **gcc**. En
  distros minimalistas (Arch) hay que instalarlas explícitamente.
- **Aviso Arch — `libXxf86dga`:** Arch **retiró `libxxf86dga`** de los repos oficiales en
  2019 (limpieza de Xorg), pero `ptcgraph` de FPC 3.2.2 aún la enlaza. Solución rápida:
  instalarla desde el Arch Linux Archive
  (`sudo pacman -U https://archive.archlinux.org/packages/l/libxxf86dga/libxxf86dga-1.1.5-1-x86_64.pkg.tar.zst`).
  Solución limpia para el port final (ver Fase 7): **recompilar `ptcgraph` sin DGA**
  comentando `ENABLE_X11_EXTENSION_XF86DGA1`/`_XF86DGA2` en `ptc/src/x11/x11extensions.inc`,
  con lo que el binario deja de depender de esa librería obsoleta.

> **Nota:** en Linux **no existe la unit `graph`** de Borland; `ptcgraph` *es* el
> reemplazo compatible con BGI. Al migrar, los `uses Graph` pasarán a `uses ptcgraph, ptccrt`.

### Tamaños de tipos en `{$MODE TP}` (relevante para leer los `.dat`)

| Tipo | BP7 (DOS) | FPC 3.2.2 `{$MODE TP}` | ¿Coincide? |
|---|---|---|---|
| `Integer` | 2 bytes | 2 bytes | ✅ |
| `Word` | 2 bytes | 2 bytes | ✅ |
| `LongInt` | 4 bytes | 4 bytes | ✅ |
| `Boolean` | 1 byte | 1 byte | ✅ |
| `packed record` (enteros/bytes/chars) | — | serializa igual | ✅ |
| `Pointer` | 4 bytes | **8 bytes** | ⚠️ |
| `Real` | **6 bytes** (sw real 48-bit) | **8 bytes** (double) | ⚠️ |

Los enteros y registros `packed` —que es como VGA Planets guarda casi todo— son
compatibles byte a byte. Atención a estructuras que embeban **punteros** o **`Real`**
si llegan a escribirse en disco (a revisar en la Fase 5).

### Entregables de la Fase 0 (en este repositorio)
- `setup-env.sh` — instala y verifica el entorno (FPC + units gráficas + prueba de compilación).
- `.gitignore` — ignora artefactos de FPC y restos de Borland.
- `.gitattributes` — normaliza finales de línea CRLF→LF y marca binarios.

### Pasos para el usuario (en tu máquina)
```bash
# 1. Verificar/instalar el entorno
bash setup-env.sh

# 2. Inicializar el repositorio con la 3.67 intacta
git init
git add .            # incluye el fuente 3.67 + .gitignore/.gitattributes
git commit -m "Importar VPA 3.67 (base de referencia intacta)"

# 3. Crear la rama de trabajo
git switch -c port-linux
```

---

## 6. Receta de migración por fichero (patrones recurrentes)

Aprendido al portar la primera unit (`UNIT/STRF.PAS`). Estos patrones se repetirán:

1. **Directivas Borland de segmento/overlay** → eliminar. `{$C MOVEABLE PRELOAD PERMANENT}`
   y similares no tienen sentido en Linux (FPC solo emite un *warning* "Illegal compiler
   directive", pero conviene quitarlas).
2. **`{$V-}` (var-string checks)** → añadir tras la declaración de unit. BP7 lo tenía global
   en `BPC.CFG` (`/$V-`); sin él, FPC en modo TP da *"String types have to match exactly in
   $V+ mode"* al pasar p.ej. un `string[20]` a un parámetro `var s:string`. No hay flag de
   línea de comandos para `$V`, así que va como directiva en el fuente (parte del "prólogo"
   estándar de cada fichero portado).
3. **Ensamblador en línea de 16 bits** → reescribir en Pascal puro. El asm con registros de
   16 bits y segmentos (`les`/`lds`, `ES:`/`DS:`, `AX/BX/SI/DI`, `jcxz`, `repne scasb`…) no
   compila en x86-64. Se reescribe la rutina en Pascal y **se valida que el comportamiento
   coincide** con un pequeño banco de pruebas (no basta con que compile).
4. **Encoding** → preservar los bytes originales. Varios ficheros tienen tablas/textos en
   codificación **DOS de un solo byte** (p.ej. `UChr`/`LChr` en STRF con acentos). No dejar
   que el editor los convierta a UTF-8 o esas tablas se corrompen. Tocar solo las partes ASCII.

> **Estado:** `UNIT/STRF.PAS` portado, compila limpio y validado funcionalmente
> (`ItemPos`/`ItemStr` reescritas desde asm). Es la primera unit hoja verde del árbol.

### Herramienta `preport.py`

Automatiza los pasos **mecánicos** (1, 2 y 4) de la receta: normaliza EOL preservando
el encoding original, elimina `{$C ...}`, e inserta `{$V-}`. Lo que requiere criterio
(asm, interrupciones, puertos, `uses Graph/Dos/WinAPI`) **no lo toca**: lo detecta y avisa
con número de línea, y devuelve código de salida 2 si queda trabajo manual (0 si limpio).
Peca de avisar de más a propósito (p.ej. marca asm/`int` aunque esté en comentarios) para
no dejar pasar nada real.

```bash
python3 preport.py UNIT/VHLP.PAS              # vista previa (no modifica)
python3 preport.py UNIT/VHLP.PAS --in-place   # aplica y deja copia .orig
```

Units de `UNIT/` que salen **limpias** (compilan tras el preport, sin trabajo manual):
las del build vivo dependen de `ptcgraph` (`VHLP`, `VHLPMAKE`→vía `vhlp`) o son entrada
(`KEYBOARD`, `MOUSE`, Fase 3). `SYSEXT`/`MEMTEST`/`DPMI*` pertenecen al subsistema DPMI
descartado.

### Pasada mecánica global y hoja de ruta

`preport-all.sh` aplica `preport.py` a todo el build vivo de una vez (con copias `.orig`),
omitiendo descartes (`DPMI*`, `MEMTEST`, `SYSEXT`) y la capa `SVGA` a reemplazar:

```bash
bash preport-all.sh           # vista previa (no modifica)
bash preport-all.sh --apply   # aplica in-place + informe en preport-report.txt
```

Tras la pasada sobre los 40 ficheros del build vivo, el **trabajo manual restante** por
categoría (esto es la hoja de ruta de las Fases 2–4):

| Categoría | Ficheros | Fase |
|---|---:|---|
| `uses Graph` | 26 | **2** (el cuello de botella: portar la capa gráfica desbloquea la mayoría) |
| `asm` / `assembler` | 15 / 6 | 2–4 (concentrado en gráficos, init, combate) |
| `INT/Intr` | 10 | 3–4 |
| `uses Dos` | 5 | 4–5 |
| `uses WinAPI` | 1 | 3 (`MOUSE`, solo bajo `{$IFDEF DPMI}` que está OFF) |
| `Mem[]` | 3 | 4 |

> **Conclusión:** 26 de ~40 ficheros dependen de `Graph`. La migración
> `Graph` → `ptcgraph` (Fase 2) es la **llave maestra** que abre la mayor parte del árbol.
> Importante: aplicar `preport-all.sh --apply` **no** hace compilar esos ficheros (faltan
> deps y el trabajo manual), pero deja la capa mecánica hecha en todo el proyecto.

| Fase | Estado | Notas |
|---|---|---|
| 0 — Preparación del entorno | ✅ Completada | Toolchain verificado **end-to-end** en Arch (FPC 3.2.2 compila y enlaza ptcgraph). Resuelto el caso `libXxf86dga` (AUR). Pendiente solo admin: `git init` + rama + licencia. |
| 1 — Recorte y andamiaje | 🟡 En curso | VPAMM ya OFF. `vpa.cfg` generado. **Units portadas: `STRF`, `AUXF`** (compilan + validadas). `AUXF` ahora exporta `MaxAvail`/`MemAvail` (heap DOS→valor grande en Linux), centralizado para todo el núcleo. Receta de port en §6. |
| 2 — Capa gráfica (`ptcgraph`) | 🟡 En curso | Swap aplicado; SVGA fuera; `vpa.cfg`. **`SCREEN`, `TCOMBAT`, `MESSAGES` y `VPAINIT` portados y compilan.** `VPAINIT`: registro de drivers BGI → `InitGraph(D8bit, m640x480, '')` directo; quitados `mem[Seg0040]`, asm muerto y reset de CapsLock. Geometría/atributos de texto: a afinar viendo el binario. Frente actual: asm de `MSGREAD.PAS`. |
| — Features *stubeadas* (restaurar luego) | 📝 Anotado | (1) **Hull-functions** (`Enum*`) → stub vacío (ver §1). (2) **`KbdFlags`** (Shift/Ctrl) → 0. (3) **`TCOMBAT.LoadPic`**: el decodificador de sprites VGA planares (4 planos) + rotación + paleta del visor de combate se deja en *stub* (sprite en blanco); es asm autocontenido (~320 líneas), se porta como tarea aislada. `SetPal` queda no-op mientras tanto. |
| — Hallazgo VPACC/HULLFUNC | ⚠️ Bloqueo arquitectónico | El núcleo usa la API de hull-functions (`THullFuncQueryResult`, `EnumHullfuncs`) que vive en `CC/HULLFUNC.PAS`, y este depende de units **ausentes** (`phost`, `pconfig`, `lowlevel`, `global`, `swapper`, `ui`…, del proyecto PCC2). VPACC completo **no es construible**. Plan: capa de compatibilidad en `VPADATA` (datos del núcleo siempre + stub vacío de `Enum*`), y reimplementar `HULLFUNC` autocontenido usando **PCC2 como referencia** (permisiva; ver §1). `iColo/iDefense/iRace` ya añadidas (compat). |
| 3 — Entrada (ratón/teclado) | 🟡 En curso | **`MOUSE`→`ptcmouse` y `KEYBOARD`→`ptccrt` portados y validados.** `KbdFlags` (Shift/Ctrl) queda como `0` (ptccrt no lo expone) — TODO. Pendiente: llamar a `PollMouse` desde el bucle de entrada. |
| 3 — Entrada (ratón/teclado) | ⬜ Pendiente | |
| 4 — Limpieza de bajo nivel | ⬜ Pendiente | |
| 5 — E/S y portabilidad de datos | 🟡 En curso | **`RST_TRN.PAS` portado** (.rst/.trn): (des)cifrado de nombres ±13, búsqueda `ScrambledName`+`ProcessName`, lectura de registro de `PLANETS.EXE` — asm 16-bit→Pascal (0-based asm vs 1-based `ByteArr`). |
| 6 — Primer binario nativo | ⬜ Pendiente | |
| 7 — Pruebas y empaquetado | ⬜ Pendiente | |

Leyenda: ⬜ Pendiente · 🟡 En curso · ✅ Completada
