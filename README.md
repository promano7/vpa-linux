# VPA-Linux — Port nativo de VGA Planets Assistant a GNU/Linux

Reconstrucción del cliente **VPA (VGA Planets Assistant)** desde su código original
en Turbo/Borland Pascal para DOS hacia un binario **nativo de GNU/Linux**, compilado
con **Free Pascal (FPC)** y usando **`ptcgraph`/`ptccrt`** como capa gráfica en
sustitución de la BGI de Borland.

- **Código base de referencia:** VPA 3.67 (fuente de SourceForge).
- **Autor original:** Alex V. Ivlev (1993–96); mantenido posteriormente por otros.
- **Objetivo:** ejecutable Linux nativo, sin DOSBox ni dosemu.

> Estado del proyecto: **¡Jugable!** 🎉 El binario nativo carga una partida real, dibuja el
> mapa estelar y responde por completo al **teclado** (F1 ayuda, F3 mensajes, F5 simulador
> de combate, navegación…) y al **ratón** (mover, seleccionar, scroll al borde). La ayuda
> (`VPA.HLP`) se renderiza, el consumo de CPU en reposo es ~0 y el puntero se comporta con
> normalidad. El **simulador de combate** y las **StarBases** muestran los sprites de las naves,
> la ventana es **escalable** y admite **pantalla completa** (`VPA_SCALE`), y la salida distingue
> guardar (**Alt-X** / botón **[X]**) de salir sin guardar (**Ctrl-Alt-X**, con confirmación).
> La **diana blanca** propia de VPA se muestra como cursor dentro de su ventana (solo ahí,
> sin afectar al resto del escritorio), auto-escalada al tamaño de la ventana.
> Este documento se actualiza a medida que avanzamos.

> **Entorno verificado** (FPC 3.2.2 / Ubuntu 24.04): las units `ptcgraph`, `ptccrt`,
> `ptcmouse` y el backend `ptc` están disponibles (paquete `fp-units-gfx`), el toolchain
> compila y enlaza programas `ptcgraph`, y el binario resultante depende de **libX11**
> (será una app X11; en Wayland funciona vía XWayland). Detalles en
> [§5 Entorno de desarrollo](#5-entorno-de-desarrollo-verificado).

---

## 1. Análisis de licencia

> 📄 **Resumen de licencia y textos completos: [`LICENSE.md`](LICENSE.md)** (con una copia de
> la MPL en [`MPL-2.0.txt`](MPL-2.0.txt)). En corto: el código de **VPA** (y sus modificaciones)
> sigue bajo **MPL**; lo portado de **PCC2/PCC2ng** bajo los *PCC II License Terms* (tipo BSD);
> los ficheros vendorizados de **Free Pascal** bajo **LGPL** con excepción de enlace estático; y
> el **código nuevo del port** bajo **BSD 3-Clause**, © 2026 Pablo Romano. Atribución:
> *«based on original work published at <https://sourceforge.net/projects/vpa/> under the MPL license»*.
> Esta sección conserva el análisis detallado que llevó a esa decisión.

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
| `CC/` (código PCC) | Stefan Reuther | Términos en `CC/README` y §1 (PCC2/PDK). Se conserva en el build. |
| ~~Subsistema DPMI~~ (eliminado) | Stefan Reuther (D4TP, © 2000-02) | **Eliminado del port** junto con su licencia `UNIT/DPMI.TXT` (era solo para DOS). |
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

1. **Situación aclarada con Stefan Reuther (PCC/PDK).** Consultado sobre la ausencia de
   `LICENSE`/`COPYING` en el paquete, confirma que **nunca los hubo**: por lo que ve en el
   historial git de SourceForge, Alex Ivlev pasó el código a Alexander Babanov
   (`lastberserker`), que lo subió a SourceForge; la etiqueta **MPL** vive solo como metadato
   del proyecto. Su recomendación de cara a publicar: añadir un `README` que apunte al
   repositorio original («*based on original work published at &lt;link&gt; under MPL license*»)
   y un fichero `LICENSE` con la **MPL** (o una compatible). Este es el plan para el cierre de
   licencia previo a publicar (Fase 7).
2. Para el código de **Stefan Reuther** que se conserva (`CC/`, PCC), los términos están en
   `CC/README` y en §1 (PCC2/PDK). Su **subsistema DPMI** (D4TP) se ha **eliminado** del port
   (era exclusivo de DOS), y con él su licencia `UNIT/DPMI.TXT`. Sigue activo en la comunidad
   VGA Planets (PCC2, c2nu…) por si hiciera falta consultarle.
3. Conservar todos los avisos de copyright (Ivlev, Reuther y demás) en la versión derivada.

> **Nota MPL 1.1 + GPL:** la MPL 1.1 por sí sola se considera incompatible con la GPL.
> Esto **no afecta** a este port: FPC RTL y `ptcgraph` están bajo *LGPL modificada*
> (con excepción de enlazado), que no impone obligaciones tipo GPL. Solo sería relevante
> si en el futuro se incorporase código estrictamente GPL.

### Fuentes de referencia externas (PCC2 / PDK)

Para la lógica de hull-functions se dispone del código de Stefan Reuther como
**referencia**. (Ojo: el `CC/HULLFUNC.PAS` que acompaña al fuente es en realidad la
unit de **PCC** —Streu, 2005-06—, con dependencias ausentes del ecosistema PCC 1.x;
**VPA implementa su propia versión** —el modelo *antiguo*— en `VPADATA.PAS`.) Las
fuentes de Reuther son C/C++, **no contienen units Pascal** drop-in, pero documentan
la lógica y el formato de datos para referencia:

| Fuente | Contenido útil | Licencia |
|---|---|---|
| **PCC2** (`pcc-v2`, 2025) | `game/hullfunc.cc/.h` (lógica hull-functions en C++) | **Permisiva tipo BSD** ("PCC II License Terms": retener copyright, marcar modificaciones). © 2001-2024 Stefan Reuther & contributors. **No es GPL.** |
| **PDK** (`pdk`, 2010) | `hullfunc.c`, `pconfig.c` (`hullHasSpecial`, `HullDoesAlchemy`, `HullCanHyperwarp`…) | **GPL v2 o posterior.** © 1995-2000 Andrew Sterian, Thomas Voigt, Steffen Pietsch (+ M. van Rees, S. Reuther). |
| **PCC2ng** (`c2ng`, 2025) | `game/vcr/classic/pvcralgorithm.cpp` (algoritmo de combate **PHost** y su interfaz `Visualizer`) — base del visor de combate nativo (ver §7) | **Permisiva tipo BSD** (*PCC II License Terms*). © Stefan Reuther & contributors. **No es GPL.** |
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

**Estado (resuelto, sin traducir el PDK):** se evaluó usar el PDK como base de
traducción, pero resultó **innecesario** para el modelo de datos de VPA. VPA no usa el
modelo moderno de hull-functions de PHost (sobre el que opera `hullfunc.c` del PDK), sino
el **modelo antiguo**: un array `HullFunc^` con funciones 0..19 que se carga en
`CONFIG.PAS` (desde `DefaultHullFunc` + los ajustes del host). Para ese modelo, la función
existente `IsHullFunc` ya equivale al `hullHasSpecial` del PDK. Por eso se implementaron
`IsShipFunc3` y `ShipOrHullDoes` (que estaban en *stub* a `False`, deshabilitando la
detección de **chunnel** en flota y de **cloak avanzado**) **puenteando** los códigos
`SPC_*` al modelo antiguo: los `SPC_*` 0..19 coinciden con el ordinal de `HullFuncs`; los
≥20 (ChunnelSelf/Others/Target, HardenedCloak…) son refinamientos de PHost que el modelo
antiguo agrupa en `hfChunneling`/`hfCloak` y se ignoran sin pérdida real para este modelo.
El PDK sirvió para **confirmar** la numeración `SPC_*` y la semántica «ship-or-hull», pero
no se tradujo código suyo.

La capa `Enum*` estilo PCC2 (`EnumHullfuncsForShip`, p. ej. la pantalla de detalle con la
**lista completa** de habilidades de la nave) sigue **solo** bajo `{$IFDEF VPACC}`, que está
**desactivado**; portarla sí requeriría el modelo moderno (PDK/PCC2) y los datos
`hullfunc.txt`/`shiplist.txt` — queda **pendiente y opcional**.

### Ficheros vendorizados de Free Pascal (`VENDOR/`)

Para ofrecer una **ventana más grande opcional** (variable `VPA_SCALE`) sin cambios
peligrosos de modo de vídeo ni "fullscreen" del gestor de ventanas, el port incluye en
`VENDOR/` una copia de varios ficheros de **Free Pascal** y **aplica un parche mínimo**
a uno de ellos:

| Fichero | Estado | Para qué |
|---|---|---|
| `ptcgraph.pp` | **Modificado** (parche VPA) | Lee la escala (`VPAForceScale`/`VPA_SCALE`) y crea la "consola" de `ptc` más grande manteniendo la superficie en 640×480; `ptc` la escala. Lleva además `{$mode objfpc}` y `sysutils` para compilar dentro del build de VPA. La cabecera incluye un **aviso visible de modificación** (lo exige la LGPL). |
| `ptcmouse.pp` | **Sin modificar** | Necesario para recompilar `ptcgraph` de forma autocontenida (FPC lo reconstruye contra el `ptcgraph` parcheado, evitando un desajuste de versión de `.ppu`). |
| `ptccrt.pp` | **Modificado** (parche VPA) | Base para recompilar `ptcgraph` autocontenido, y además lleva varios parches VPA en el manejo de teclado: expone `PTCLastKbdFlags` (Shift/Ctrl/Alt del último evento, usado como reserva), trata el botón **[X]** de la ventana como **Alt-X** (salir guardando) y marca `PTCQuitNoSave` para **Ctrl-Alt-X** (salir sin guardar), y emite **Alt+flecha** (`$9B/$9D/$98/$A0`) también en modo `kmTP7` —el de VPA—, no solo en `kmGO32/kmFPWINCRT` (restaura el comportamiento del TP7 de DOS). Con su aviso de modificación. |
| `ptc/` (`core/` + `x11/`, ~556 KB) | **2 ficheros modificados** (`x11/x11extensions.inc`, `x11/x11windowdisplayi.inc` + su `.d.inc`) | Backend que hay debajo de `ptcgraph`. Se vendoriza para recompilarlo **sin las extensiones X11 DGA** (`x11extensions.inc`: solo se comentan los dos `{$DEFINE …XF86DGA1/2}`) y que el binario no dependa de `libXxf86dga` (retirada de Arch). Además, `x11windowdisplayi.inc`/`.d.inc` llevan la **diana blanca de VPA como cursor** de la ventana (cruz simétrica, auto-escalada, por-ventana; ver §7 «Estado actual (runtime)» punto 13). Todos los cambios con su aviso de modificación; el resto va íntegro. El `Makefile` (objetivo `ptc`) lo recompila a `build/ptcunits/`. |
| `graphh.inc`, `graph.inc`, `clip.inc`, `fills.inc`, `fontdata.inc`, `gtext.inc`, `modes.inc`, `palette.inc` | **Sin modificar** | Includes que arrastra `ptcgraph`. |

**Licencia de estos ficheros:** son parte de la **Free Pascal run-time library**, bajo la
**LGPL modificada con excepción de enlazado estático** (la misma con la que se distribuye
FPC). Se conservan **íntegras todas las cabeceras de copyright** (Nikolay Nikolov, Daniel
Mantione y el equipo de FPC). Los ficheros modificados —`ptcgraph.pp` y `ptc/x11/x11extensions.inc`— llevan en su
cabecera un aviso de modificación, tal como exige la LGPL.

**Por qué no rompe el objetivo de licencia:** la LGPL (con excepción de enlazado) es
**compatible con GPL**: estos ficheros pueden combinarse y redistribuirse dentro de un
proyecto que en su conjunto sea GPL. Vendorizar copias (en lugar de solo enlazar contra el
FPC del sistema) es legítimo bajo la LGPL siempre que —como aquí— se conserven los avisos y
se marquen los cambios. En la práctica:

- Las partes **propias del port** (código de VPA traducido/adaptado, `UNIT/xfocus.pas`,
  arreglos…) quedan bajo la **licencia libre elegida para el port** (compatible con GPL).
- Los ficheros de `VENDOR/` **siguen bajo su LGPL modificada** original; no se relicencian.
- El binario final enlaza con `libX11`/FPC, todo bajo licencias libres compatibles.

> Si se prefiere **no vendorizar**: basta con borrar `VENDOR/` y quitar `-FuVENDOR`/
> `-FiVENDOR` de `vpa.cfg`. El port vuelve a enlazar contra el `ptcgraph` del sistema y la
> ventana queda fija en 640×480 (se pierde solo la opción `VPA_SCALE`).

*Aviso: este análisis es informativo, no asesoramiento legal.*

---

## 2. Análisis del código base

Métricas reales medidas sobre el fuente **3.67** (solo ficheros `.pas`):

| Módulo | Ficheros | Líneas | Rol | Destino en el port |
|---|---:|---:|---|---|
| `VPA/` | 26 | 40.390 | Núcleo de la aplicación | **Migrar** |
| `VPAMM/` | 11 | 8.349 | «Modo mixto»: DPMI + VESA + kernel propio | **Descartado (eliminado del repo)** |
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
- [x] Inicializar repositorio git e importar la 3.67 **intacta** como base de referencia. ✅ Hecho: subida en el 3.er commit (`Updated README.md and uploads original source code`); los dos primeros commits eran el README inicial y su actualización.
- [x] Rama de trabajo. ✅ El desarrollo va en **`main`**. Al cerrar el primer binario nativo se **congelará** el estado como rama **`3.67`** (release) y `main` seguirá como rama de desarrollo para correcciones y mejoras futuras.
- [x] Añadir `.gitignore`, `.gitattributes` y `setup-env.sh` (entregables de esta fase, ya generados).
- [x] Resolver/anotar el tema de licencia (contacto con mantenedor si se prevé distribuir). ✅ **Anotado y contactado**: el análisis completo está en §1, y se consultó a **Stefan Reuther** (PCC/PDK), que confirma que nunca hubo `LICENSE`/`COPYING` en el paquete —solo el metadato **MPL** de SourceForge— y recomienda, de cara a publicar, añadir un `README` que apunte al repositorio original («based on original work published at &lt;link&gt; under MPL license») y un fichero `LICENSE` con la MPL (o una compatible). El cierre efectivo (añadir el `LICENSE`) queda para antes de publicar (ver Fase 7).
- [x] Convertir finales de línea CRLF→LF (lo gestiona `.gitattributes`) y documentar codificación de los textos.

### Fase 1 — Recorte y andamiaje de compilación
- [x] **VPAMM ya está desactivado** por defecto (`{.$DEFINE VPAMM}` en `switches.inc`): el build estándar de `vpa.pas` no lo incluye. No hay que tocar el núcleo para sacarlo.
- [x] **Carpeta `VPAMM/` descartada y eliminada del repositorio.** Era la variante "modo mixto" de DOS (DPMI + VESA + kernel gráfico propio: `DRIVERS`, `AAVESA`, `AAFONT`, `VESA256`, `VGA640`, `GRAPH`…). El símbolo `VPAMM` nunca se define en el port (los bloques `{$IFDEF VPAMM}` compilan a nada) y la capa gráfica es `ptcgraph`, no esos drivers. Verificado que `vpa.pas` **compila y enlaza sin la carpeta** (no está en las rutas `-Fu` de `vpa.cfg` ni la usa ningún `uses`/`{$I}` del build vivo). Las units DPMI de `UNIT/` (`DPMI`, `DPMITEST`, `MEMTEST`, `SYSEXT`) solo las usan programas de prueba descartados; pendientes de eliminar aparte (ver Fase 4).
- [x] `vpa.cfg` para FPC en modo `{$MODE TP}` con las rutas de units del proyecto + ptcgraph (ruta Arch verificada). *(Sustituye a `BPC.CFG`.)*
- [x] **`Makefile` para FPC** (sustituye al de Borland Make): objetivos `build`/`clean`/`run`/`help`. Build con `fpc @vpa.cfg VPA/VPA.PAS`. Instrucciones completas de compilación y ejecución en **[`BUILD.es.md`](BUILD.es.md)** (o en inglés, **[`BUILD.en.md`](BUILD.en.md)**) (dependencias en Arch, ejecución con una partida, solución de problemas).
- [x] Decidir sobre `VPACC` y `TASKS`: **ambos quedan OFF** (comentados en `switches.inc`). La capa `VPACC` (`Enum*` estilo PCC2) no se activa para reducir superficie; las features que dependían de ella (hull-functions: chunnel en flota, cloak avanzado…) se resolvieron sobre el **modelo antiguo** (`IsShipFunc3`/`ShipOrHullDoes`, ver §1), sin necesidad de encender `VPACC`.
- [x] **Limpieza global de directivas Borland** sin equivalente en Linux: `{$C MOVEABLE PRELOAD PERMANENT}` (atributos de segmento/overlay DOS), etc. — strip masivo.
- [x] Primer compilado de tanteo (bottom-up, empezando por una unit hoja como `STRF`): **recoger la lista de errores reales**.

### Fase 2 — Capa gráfica (`ptcgraph`)
- [x] **Verificado: `ptcgraph` cubre el 100% de la API BGI que usa VPA** (probado compilando un programa con todas las llamadas: `Line`, `OutTextXY`, `GetImage`/`PutImage`, `Circle`, `Bar`, paletas, viewports…). Es prácticamente *drop-in*.
- [x] **`swapgraph.py`**: cambia `uses Graph`→`ptcgraph` (y `Crt`→`ptccrt`) en las cláusulas `uses` de los 22 ficheros afectados, preservando encoding. (VPA no usa `Crt`; sí `Dos` en 5 ficheros → Fase 4.)
- [x] Aplicar `swapgraph.py` a los ficheros con `uses Graph`.
- [x] **Reescribir la init de `VPA/VPAINIT.PAS`**: las ramas SVGA/CustomBGI/EGAVGA registran drivers BGI externos (`@svgaProc`, `@EGAVGADriverProc`, `@SmallFontProc`) que no enlazan en Linux. En ptcgraph `InstallUserDriver`/`RegisterBGIDriver` son no-ops; se sustituye todo el bloque por una llamada directa `InitGraph(gd,gm,'')` con un modo nativo (p.ej. `gd:=D8bit; gm:=m640x480` para 256 colores). Eliminar `SVGA.PAS`/`SVGA.OBJ`.
- [x] Reescribir `GREETS.ASM` en Pascal o eliminarla. ✅ **Descartada**: `WriteGreeting` (`VPAEXIT.PAS`) usa un stub sin datos de saludo, `GREETS.OBJ` no se enlaza y `GREETS.ASM`/`GREETS.BAT` quedan como ficheros muertos (no se compilan ni referencian).
- [x] Portar la cadena del núcleo gráfico (`SCREEN`, `VPADATA`, `Global`…) hasta compilar.
- [x] **Hito:** arrancar en modo gráfico y dibujar el mapa estelar.
- [x] **Ventana más grande opcional (`VPA_SCALE`).** La superficie de dibujo sigue siendo 640×480 (toda la UI de VPA está diseñada para ese tamaño); para agrandar la ventana sin cambiar el modo de vídeo ni usar "fullscreen" del gestor (ambos provocaron cuelgues), se **vendoriza un `ptcgraph` con un parche mínimo** que crea la "consola" de `ptc` más grande y deja que `ptc` escale la superficie 640×480 para llenarla (ver `VENDOR/` y §1). El ratón se reescala en ambos sentidos (`xfocus.MapMouseToSurface`/`MapSurfaceToWindow`) para que el clic y las flechas mantengan la precisión píxel a píxel. Opciones (variable de entorno):
  - sin definir → **escala 2 por defecto** (ventana en el escritorio);
  - `VPA_SCALE=1` → 640×480 nativo (sin escalar);
  - `VPA_SCALE=N` (2…8) → ventana N× (recortado a lo que cabe en pantalla), siempre como **ventana** en el escritorio;
  - `VPA_SCALE=fullscreen` → **pantalla completa real**: usa el ajuste 4:3 más grande que cabe (mismo número de píxeles que el `N` equivalente, nítido) y pide al gestor `_NET_WM_STATE_FULLSCREEN`, de modo que la ventana queda **por encima del panel del escritorio** (resuelve el scroll hacia abajo en escritorios con panel inferior). Las zonas 16:9 sobrantes quedan a los lados (4:3). Se sale con **Alt-X** como siempre. Es seguro y recuperable: la pantalla completa se aplica a la **propia ventana de VPA** (no cambia el modo de vídeo del monitor) y al cerrar se libera explícitamente, así que el panel reaparece.
    - La ventana se **agranda hasta llenar la pantalla** (algunos gestores solo ocultan el panel si la ventana cubre todo el monitor); como `ptc` pinta su contenido en la esquina superior izquierda, el contenido 4:3 queda pegado a la izquierda con una franja negra a la derecha (se ve completo y sin distorsión).

### Fase 3 — Entrada: ratón y teclado
- [x] Reescrito `UNIT/MOUSE.PAS` sobre `ptcmouse` (sondeo de eventos con `PollMouse`) en lugar de INT 33h + handler en asm. Detecta flancos (move, press/release de cada botón) comparando estado previo/actual y despacha a `HandlerTable`.
- [x] Reescrito `UNIT/KEYBOARD.PAS` sobre `ptccrt` (`ReadKey`, `KeyPressed`, `PreviewKey`).
- [x] **Mapeados los scancodes BIOS** ($3B00=F1, etc.): `ReadKey` devuelve el ascii en el byte bajo o el scancode en el byte alto para teclas extendidas.
- [x] **`PollMouse` conectado al bucle de entrada:** se llama desde `KeyPressed` (no desde `FastKeyPressed`, reservado a bucles de animación). Cadena verificada: bucle principal → `KeyPressed` → `PollMouse` → `Dispatch(EvLtPress…)` → `MouseHandler` fija `mEvent` → el bloque `while mEvent<>0` ejecuta la acción. Compila, enlaza y arranca.
- [x] **Prueba interactiva** (con partida real): navegar mapa y menús con ratón — **validado jugando** (mapa, planetas, StarBases, combate…). **Shift/Ctrl/Alt: resuelto** — `KbdFlags` consulta el estado actual de modificadores a X11 (`XQueryPointer`, estilo BIOS `0040:0017`), validado por inyección (Shift→3, Ctrl→4, Alt→8) tanto en atajos de teclado como en ratón+modificador (zoom del mapa).
- [x] **Hito:** navegar por el mapa y los menús con ratón y teclado.

### Fase 4 — Limpieza de bajo nivel (UNIT + núcleo)
- [x] **Eliminados** `UNIT/DPMI.PAS`, `UNIT/DPMITEST.PAS`, `UNIT/MEMTEST.PAS`, `UNIT/SYSEXT.PAS` (subsistema DPMI de DOS), más los binarios DOS muertos `UNIT/DPMI.TPU`/`UNIT/SYSEXT.TPU` y la doc/licencia `UNIT/DPMI.TXT`. Verificado que nada vivo los usa y que `vpa.pas` compila y enlaza sin ellos. `DPMI` solo lo usaban `DPMITEST`/`MEMTEST` (programas de prueba, también fuera).
- [x] Revisar `UNIT/AUXF.PAS` y `UNIT/STRF.PAS`: sustituir asm por Pascal/intrínsecos de FPC. ✅ **Hecho** (durante el port inicial de estas units hoja). Ambos ficheros son **100% Pascal**, sin una sola línea de ensamblador: `AUXF` usa intrínsecos de FPC (`CompareByte` en `Diff`, `Sleep` en `Delay`, `GetTickCount64` en `Timer`, `SysUtils`) y `STRF` reescribió las rutinas que eran asm x86 (`ItemPos`/`ItemStr`, originalmente `repne scasb`) en Pascal puro y portable. Verificado funcionalmente.
- [x] Tratar las ~11 interrupciones y ~29 líneas de asm del núcleo, fichero a fichero (hora del sistema, etc.). ✅ **Hecho.** Barrido exhaustivo del núcleo (excluyendo comentarios y bloques `(* *)`): **cero interrupciones vivas** (`Intr`/`MsDos`/`Registers`), **cero puertos** (`Port[`), **cero memoria-DOS** (`Mem[`/`Seg0040`) y **cero asm vivo**. Las cifras "~11/~29" eran del análisis del 3.67 original (§2); se resolvieron durante el port — reescritas en Pascal (lo documentan los comentarios «asm original» en `MESSAGES`/`VPA2`/`VPAINIT`) o quedaron como código muerto comentado (los dos bloques asm de `SCRSAVER.PAS`, efectos del salvapantallas deshabilitados). Que el binario compile y enlace en x86-64 lo confirma: el asm 16-bit o las interrupciones DOS ni compilarían.
- [x] Clasificar los `absolute` del núcleo: *aliasing* (se queda) vs. acceso a hardware (se reescribe). ✅ **Hecho** (auditoría): de **142** `absolute` vivos en el núcleo, los **142 son aliasing de variable** (type-punning portable: `ls:byte absolute s` para el byte de longitud de un string; `SRec/PRec/MRec absolute b` para reinterpretar un buffer como distintos records — idioma unión). **Cero** de forma hardware (`absolute segmento:offset` o dirección numérica), coherente con que compile en x86-64 (esa forma ni compilaría). Son portables para el objetivo little-endian; el desempaquetado de records leídos de disco ya está cubierto por `{$PACKRECORDS 1}` y la nota de endianness de la Fase 5.

### Fase 5 — E/S de ficheros y portabilidad de datos *(crítica)*
- [x] **Tamaños de tipos** *(verificado en §5)*: en `{$MODE TP}` con FPC 3.2.2 x86_64, `Integer`=2, `Word`=2, `LongInt`=4 bytes (idénticos a BP7). **Dos trampas confirmadas:** `Pointer`=8 bytes (era 4) y `Real`=8 bytes (en BP7 era de **6 bytes**). **Resuelto:** los records que van a disco (`SRec`, `STRec`, `MRec`, `URec`, combate…) contienen solo `int`/`char`/`long`/`byte`/`boolean` — **ningún `pointer` ni `real` dentro** (auditado), así que no hay desajuste de tamaño. El único `Pointer`→entero problemático estaba en el display de dirección de error (`VPA.PAS`, manejador de fallos); corregido con `PtrUInt`.
- [x] **Empaquetado de records (CRÍTICO, resuelto).** Turbo/Borland Pascal **siempre** empaqueta records sin relleno; FPC en modo TP **alinea a 2 por defecto**, insertando padding tras campos de tamaño impar (p. ej. `fcode` de 3 bytes en `SRec`) y desalineando lo leído de los `.DAT`. Verificado: `SizeOf(SRec)`=124 con relleno vs **123 byte-packed** (`name` en offset 46 vs 45). Solución: `{$PACKRECORDS 1}` en `switches.inc` (incluido por todas las units) → layout idéntico al de DOS. Binario recompila, enlaza y arranca.
- [x] **Endianness (validado + guarda).** Los ficheros de VGA Planets (`.DAT`/`.RST`/`.TRN`/`VPAx.DB`) son **little-endian** (formato x86 de DOS) y VPA los lee/escribe crudos con `BlockRead`/`BlockWrite` sobre records empaquetados, sin conversión. Esto es correcto en **todos los targets Linux realistas** (x86-64, ARM64, ARM32, RISC-V… todos little-endian por defecto), así que en **ARM funciona igual que en x86**. Para no corromper datos en silencio en un hipotético target **big-endian** (que necesitaría byte-swapping, no implementado), se añadió una **guarda de compilación** en `switches.inc`: `{$IFDEF ENDIAN_BIG}{$FATAL …}{$ENDIF}` — inerte en little-endian, y en big-endian **aborta la compilación con un mensaje claro** en vez de generar un binario que corrompería las partidas. Verificado que la guarda es inerte en x86-64 y que dispara correctamente (probado invirtiendo la condición).
- [x] **Separador de rutas DOS→Linux (RESUELTO).** `OpenRW`/`OpenData` anteponen el directorio de partida (`addir`) a cada nombre, y `VPAINIT` le añadía un `\` de DOS → `LUPUS4\GEN5.DAT` no existe en Linux. Cambiado a `/`. (`OpenData` ya prueba `addir+name` y cae a `name` en el directorio actual, así que los ficheros maestros como `PLANET.NM` se localizan bien.)
- [x] **Comprobaciones de runtime (RESUELTO).** El `BPC.CFG` original desactivaba E/S, rango, overflow y pila (`/$I-,R-,S-,Q-`) globalmente; el código asume `{$I-}` (comprueba `IOResult` tras `Reset`, sin excepciones). Sin ello, un fichero ausente lanzaba `EInOutError 217` al arrancar. Replicado en `vpa.cfg` con `-Ci- -Cr- -Co- -Ct-` (aplica a todas las units, también las que no incluyen `switches.inc` como `INI`). Verificado: el binario arranca, escribe su config y lee los datos de la partida desde el directorio indicado.
- [x] **Rutas mayúsculas/minúsculas (RESUELTO).** Las partidas reales mezclan mayúsculas y
  minúsculas (p. ej. PHOENIX4 trae `GEN7.DAT` en mayúsculas pero `pconfig.src`, `beamspec.dat`,
  `torpspec.dat`, `race.nm`… en minúsculas). VPA construía los nombres en mayúsculas y en un
  sistema de ficheros sensible a may/min **no abría** esos datos → caía a valores por defecto
  (¡incluido `AllowAlternativeCombat=No`!), alterando el combate. Solución: `ResolveCase` en
  `CONFIG.PAS` y `VPADATA.PAS` (resuelve el nombre real escaneando el directorio sin distinguir
  may/min); aplicado en `ReadConfigFile`, `OpenData`, `Exists`, `OpenRW` y `OpenText` (el lector
  de texto genérico), y en las lecturas de config distribuidas (`RACES.INI`, `MISSION.INI`,
  `VPADATA.INI`, `VPACLR.INI`). Nombres 8.3 (`GEN5.DAT`…) no dan problema en Linux; el `vpa.ini`
  propio de VPA se deja sin `ResolveCase` (caja consistente al crearlo/leerlo; envolverlo
  arriesgaría una asimetría lee-resuelto/escribe-original al renombrar).
- [x] Adaptar el manejo de errores de Borland (`ExitProc`, `ExitCode`, `ErrorAddr`, procedimientos `far`) al equivalente de FPC.

### Fase 6 — Primer binario nativo
- [x] **Iterar hasta lograr compilación limpia y un ejecutable que arranque.** ✅ **HITO: todas las units compilan y enlazan en un binario ELF de 64 bits.** Arranca bajo X11 (probado con Xvfb): inicializa `cthreads`, abre el display, imprime el banner y la ayuda de uso, y sale limpiamente al no recibir raza/directorio. `34064` líneas compiladas, 25 warnings.
- [x] **Warnings de rango y de puntero corregidos:** las constantes fuera de rango de byte se debían al camino VPACC-off nunca compilado en el original — `VPA4` (`chr($5300)` de la tecla DEL, que se trunca a `chr(0)` como en DOS) → explicitado a `chr(0)`; `CONFIG` (`byte(key)-byte(kFF1)+1` con un enum que cruza 256) → `ord(...)`. El truncado de puntero de 64 bits en el display de error (`VPA.PAS`, `long(ErrorAddr)`) → `PtrUInt`. Quedan solo warnings benignos de FPC (switches `$E/$L/$N` ignorados, comparaciones siempre true/false, alguna variable sin inicializar) sin impacto.
- [x] **`PollMouse` conectado al bucle de entrada principal** (vía `KeyPressed`; ver Fase 3).
- [x] Probar con datos reales de una partida (RST/TRN) — requiere un directorio de juego con `GENx.DAT`, `SHIPx.DAT`, etc.

### Fase 7 — Pruebas, empaquetado y (opcional) distribución
- [ ] Comparar comportamiento contra la versión DOS en DOSBox.
- [ ] Empaquetar (binario + ficheros de soporte: `vpa.hlp`, `vpa.msg`, recursos).
- [ ] Cerrar el tema de licencia si se publica.
- [x] *(Opcional, fase posterior)* Evaluar 256 colores / resoluciones mayores, o un backend SDL para modernización real. ✅ **256 colores hecho** (el port corre en `D8bit`/m640x480, 256 colores) y **resoluciones mayores hechas** vía `VPA_SCALE` (ventana N× y pantalla completa, manteniendo la superficie 640×480). Un **backend SDL** queda como **futuro opcional** (no necesario: `ptcgraph` cubre la API BGI; `sdlgraph` está reportado como roto por FPC).
- [x] **Eliminada la dependencia de `libXxf86dga`.** Se vendoriza el backend `ptc` (solo `core/` + `x11/`, ~556 KB) en `VENDOR/ptc/` con las extensiones X11 `XF86DGA1`/`XF86DGA2` desactivadas en `x11/x11extensions.inc`; el `Makefile` (objetivo `ptc`) lo recompila a `build/ptcunits/` y `vpa.cfg` lo antepone al `ptc` del sistema. Verificado con `ldd`: el binario ya **no** enlaza `libXxf86dga` (VPA siempre usa la consola X11 en ventana, nunca DGA, así que no se pierde nada).

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
  -lXi -lXrandr -lXxf86vm` (ya **no** `-lXxf86dga`, ver el aviso de Arch más abajo) y
  necesita los objetos `crt*.o` de **gcc**. En distros minimalistas (Arch) hay que
  instalarlas explícitamente.
- **`libXxf86dga` (RESUELTO).** Arch **retiró `libxxf86dga`** de los repos oficiales en
  2019 (limpieza de Xorg), pero el `ptc` de FPC 3.2.2 la enlazaba por las extensiones X11
  DGA. **Ya no hace falta** ningún paquete extra: el port **vendoriza `ptc` sin DGA** (ver
  §1 y Fase 7) — el `Makefile` lo recompila con `XF86DGA1`/`DGA2` desactivados y el binario
  resultante no enlaza `libXxf86dga`. (El antiguo apaño de instalarla desde el Arch Linux
  Archive ya no es necesario.)

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
| 0 — Preparación del entorno | ✅ Completada | Toolchain verificado **end-to-end** en Arch (FPC 3.2.2 compila y enlaza ptcgraph). Caso `libXxf86dga` resuelto del todo (ptc vendorizado sin DGA, ver Fase 7). `git init`/import y rama, hechos (ver §4, Fase 0); licencia contactada y anotada (Stefan Reuther), cierre formal en `LICENSE.md`/`MPL-2.0.txt` pendiente solo de publicar. |
| 1 — Recorte y andamiaje | ✅ Completada | VPAMM descartado; `vpa.cfg`/`Makefile` para FPC. **Todas las units del núcleo portadas y compilan** (`STRF`, `AUXF` y el resto vía la receta de este §6). `GREETS.ASM` descartada (stub en `VPAEXIT`). |
| 2 — Capa gráfica (`ptcgraph`) | ✅ Completada | Swap aplicado; SVGA fuera. `SCREEN`, `TCOMBAT`, `MESSAGES`, `VPAINIT` y el resto del núcleo gráfico portados, compilan y **dibujan el mapa estelar real**. `VPAINIT`: `InitGraph(D8bit, m640x480, '')` directo (sin drivers BGI externos). Sprites de naves/combate, StarBases y salvapantallas funcionando (ver «Estado actual (runtime)», punto 8). |
| — Features *stubeadas* (restauradas) | ✅ Resuelto | (1) **Hull-functions**: `IsShipFunc3`/`ShipOrHullDoes` **implementados** sobre el modelo antiguo (ver §1 y «Estado actual»); solo la capa `Enum*` estilo PCC2 sigue bajo `{$IFDEF VPACC}` (off, decisión tomada). (2) **`KbdFlags`** (Shift/Ctrl/Alt) → **resuelto** (estado actual vía X11 `XQueryPointer`). (3) **`TCOMBAT.LoadPic`**: el decodificador de sprites VGA planares (4 planos) + paleta + rotación del visor de combate **portado** a Pascal; `SetPal` implementado. |
| — Capa compat VPACC/HULLFUNC | ✅ Desbloqueado | Añadida a `VPADATA` (rama `{$IFNDEF VPACC}`): vars de estado (`BL0`, `bOver`, `mt0/mt1`, `MineN`…), consts (`iBeam`…`iRace`), ~40 `SPC_*`, tipo `THullFuncQueryResult`, declaración de `IsHullFunc`. `IsHullFunc` (asm) portado a Pascal; **`ShipOrHullDoes`/`IsShipFunc3` implementados** puenteando los `SPC_*` al modelo antiguo (chunnel en flota y cloak avanzado ya se detectan). **`VPA4`, `VPA2`, `CONFIG` compilan.** |
| — Warnings de rango y de puntero | ✅ Resuelto | Las constantes fuera de rango de byte del path VPACC-off (`VPA4:1626`, `CONFIG:517/703`) y el truncado de puntero de 64-bit (`VPA.PAS`, error handler) quedaron corregidos (ver §4, Fase 6): explicitados/`ord(...)`/`PtrUInt`. Solo quedan warnings benignos de FPC sin impacto. |
| 3 — Entrada (ratón/teclado) | ✅ Completada | `MOUSE`→`ptcmouse` y `KEYBOARD`→`ptccrt` portados y validados. **`KbdFlags`** (Shift/Ctrl/Alt) resuelto vía X11 `XQueryPointer` (teclado y ratón+modificador). **`PollMouse` conectado** al bucle de entrada principal (vía `KeyPressed`). Navegación por mapa y menús con ratón y teclado **validada jugando** partidas reales. |
| 4 — Limpieza de bajo nivel | ✅ Completada | Subsistema DPMI de DOS eliminado (`DPMI*`, `MEMTEST`, `SYSEXT` y sus binarios/licencia). `AUXF`/`STRF` 100% Pascal (sin asm). Barrido exhaustivo del núcleo: cero interrupciones, puertos, memoria-DOS y asm vivo. Los 142 `absolute` del núcleo auditados: todos *aliasing* de variable (portable), ninguno de forma hardware. |
| 5 — E/S y portabilidad de datos | ✅ Completada | `{$PACKRECORDS 1}` (empaquetado idéntico a DOS), guarda de endianness para big-endian, separador de rutas `/` (antes `\`), comprobaciones de runtime replicadas (`-Ci- -Cr- -Co- -Ct-`), rutas tolerantes a mayúsculas/minúsculas (`ResolveCase`) y `RST_TRN.PAS` portado (.rst/.trn: (des)cifrado de nombres, lectura de registro de `PLANETS.EXE`). |
| 6 — Primer binario nativo | ✅ Completada | Todas las units compilan y enlazan en un binario ELF de 64 bits; arranca bajo X11. Warnings de rango/puntero corregidos. `PollMouse` conectado. **Probado con datos reales de partidas** (PHOENIX4, NORTH12…). |
| 7 — Pruebas y empaquetado | 🟡 En curso | Quedan, ligados a la publicación (ver §4, Fase 7): comparación a fondo contra la versión DOS en DOSBox, empaquetado del binario distribuible, y el cierre formal de la licencia al publicar (`LICENSE.md`/`MPL-2.0.txt` ya preparados). |

Leyenda: ⬜ Pendiente · 🟡 En curso · ✅ Completada

## 7. Visor de combate PHost nativo (port de `pvcralgorithm` de PCC2ng)

VPA tiene un visor de combate propio (`VPA/TCOMBAT.PAS`: `Combat(var vcr:VCRData; …)`,
con `Battle`, `FireBeam`, `FireTorpedo`, `LaunchFighter`, `MoveFighters`, `Hit`,
`DrawShield`, `Beam`, `Torpedo`, `Fighter`, `Gauge`, `Blast`…) y ya **reproduce VCRs de
forma nativa** (`MESSAGES.PAS` llama `Combat(vcr,Yes,…)`). El problema: ese algoritmo es el
**clásico de THost con constantes fijas** — no lee la configuración de combate de PHost —,
así que para partidas **PHost** (como las del autor, PHost 4.1h) es *aproximado*, no exacto.
Por eso el VPA original ofrecía además lanzar el visor externo `PVCR.EXE` (de PHost), que no
es open source y solo existe para DOS.

### Decisión: portar el algoritmo, no empaquetar un binario externo

Se evaluaron dos vías (ambas sugeridas por Stefan Reuther):

| | **Opción A — `playvcr` (PCC2 1.x)** | **Opción B — portar `pvcralgorithm` (PCC2ng)** |
|---|---|---|
| En el repo | PCC2 1.x + cpluslib (~20 MB C++) | ~1673 líneas de Pascal nuevas |
| Runtime | **SDL 1.2** (`sdl12-compat`) + recursos de PCC2 | **nada nuevo** (usa `ptcgraph` + sprites `RESOURCE.PLN`) |
| Aspecto | programa SDL aparte, estética PCC2 | **integrado** en VPA, su ventana y sprites |
| Exactitud PHost | exacta | exacta si se porta bien |
| Esfuerzo | bajo (empaquetar) | alto (portar matemática + validar) |

Se eligió la **Opción B**: encaja con el espíritu del port (autocontenido, sin dependencias
nuevas — justo después de habernos quitado `libXxf86dga`), y aprovecha que VPA **ya tiene la
visualización**; solo le falta el algoritmo PHost-exacto. PCC2ng separa limpiamente ambas
cosas: `game/vcr/classic/pvcralgorithm.cpp` (~1673 líneas de combate puro) emite **8 eventos**
a una interfaz `Visualizer` (`startFighter`, `landFighter`, `killFighter`, `fireBeam`,
`fireTorpedo`, `updateBeam`, `updateLauncher`, `killObject`) que mapean casi 1:1 con las
rutinas de dibujo que VPA ya tiene. Se porta el algoritmo a Pascal y se conecta a `TCOMBAT`.

> **Verificado de paso** que la Opción A *era* viable (PCC2 1.x + `playvcr` compilan limpio
> en g++ 13, binario de ~2,9 MB que solo necesita SDL 1.2). Se descarta por huella y por dejar
> un satélite ajeno, no por inviable.

### Licencia

`pvcralgorithm` viene de **PCC2ng** (`c2ng`), © Stefan Reuther, bajo los mismos *PCC II License
Terms* (permisiva tipo BSD: retener copyright y marcar modificaciones; **no** es GPL). Es
compatible con el objetivo de licencia del port. Las units Pascal portadas **conservarán la
cabecera de copyright de Reuther** y una nota de "derivado de PCC2ng".

### Plan por fases

- **Fase A — Andamiaje y mapeo de datos** (sin matemática aún) — ✅ **COMPLETADA**:
  - ✅ Unit nueva `VPA/PVCRALG.PAS` con el esqueleto: tipo `TVcrObject` (el combatiente,
    equivalente a `game::vcr::Object` de PCC2ng) y firmas `InitBattle` / `PlayCycle` /
    `PlayFastForward` / `DoneBattle` (stubs) + consultas de estado `Get*`.
  - ✅ Interfaz "visualizador" `TVcrVisualizer`: los **8 eventos** como *callbacks*
    (`startFighter` / `landFighter` / `killFighter` / `fireBeam` / `fireTorpedo` /
    `updateBeam` / `updateLauncher` / `killObject`), que `TCOMBAT` rellenará en la Fase C.
  - ✅ `MapVCR`: mapea el registro VCR de VPA (`VCRData`, leído tal cual de `VCRx.DAT`) →
    `TVcrObject`. **Verificado campo a campo por offset** contra el layout clásico de PCC2ng
    (`Vcr` = 100 bytes, `VcrObject` = 42), incluido el desempaquetado de munición de
    `database.cpp`. Todos los campos de combate están disponibles.
  - ✅ **Parser de `PCONFIG.SRC` extendido** (`CONFIG.PAS`): se capturan las **30 claves de
    combate** de PHost que el algoritmo necesita (`BeamHitOdds`, `BeamHitBonus`,
    `BeamRechargeRate/Bonus`, `TorpHitOdds/Bonus`, `TubeRechargeRate/Bonus`,
    `BayRechargeRate/Bonus`, `BayLaunchInterval`, escalados de escudo/daño/tripulación,
    `MaxFightersLaunched`, `StrikesPerFighter`, `FighterMovementSpeed`,
    `FighterBeamExplosive/Kill`, `FighterFiringRange`, `FighterKillOdds`, `BeamFiringRange`,
    `BeamHitFighterRange/Charge`, `BeamHitShipCharge`, `TorpFiringRange`,
    `FireOnAttackFighters`, `StandoffDistance`, `PlanetsHaveTubes`). Se guardan en el registro
    `CombatCfg : TCombatCfg` (VPADATA), casi todas **por jugador** (`IArr11`); las distancias
    y rangos en `LArr11` (32-bit, porque superan 16 bits — p. ej. `BeamHitFighterRange`=100000).
    `InitCombatCfgDefaults` fija los **defaults de PHost** (de PCC2ng) antes de leer el fichero.
    Implementado con un despachador `ReadCombatKey` enganchado al bucle de parseo **sin tocar la
    tabla posicional `KeyNames`** (riesgo cero para la config existente). Las claves `EMod*`
    (experiencia) se implementaron en la **Fase F** (helper `GetEMod`, arrays por nivel).
- **Fase B — Portar el algoritmo** (la matemática), por bloques de menor a mayor dependencia — ✅ **COMPLETADA Y VALIDADA BIT-EXACTA**:
  1. `initBattle` + precálculo de config (hit odds, recharge rates, kill/damage).
     ✅ **Precálculo portado y verificado bit-exacto** (`InitBattle` en `PVCRALG.PAS`,
     modelo entero `PVCR_INTEGER`): estructuras de estado `TFixedStatus`/`TRunningStatus`
     por lado; `ComputeBeamHitOdds`/`ComputeBeamRechargeRate`/`ComputeTorpHitOdds`/
     `ComputeTubeRechargeRate`/`ComputeBayRechargeRate` (fórmulas de PHost), `DivRound`
     (`ccvcr.pas:RDiv`), `EMV` (`getExperienceModifiedValue`, con soporte de experiencia añadido
     en la Fase F) y la caché de
     opciones de config; specs de armas desde `Beams[]`/`Torps[]` de VPA (`kill`/`expl` =
     kill/damage power). Validado contra una referencia C++ con varias entradas (incluidos
     casos que rebosan 16-bit → `beam_hit_odds`/`torp_hit_odds` son 32-bit, como en PCC2ng).
     Añadido `ShipMovementSpeed` al parser de config (faltaba en Fase A).
  2. RNG de PHost (debe ser **bit-exacto**) y recarga de beams/launchers/bahías.
     ✅ **RNG portado y verificado bit-exacto** (`Random64k`/`RandomRange`/`RandomRange100`/
     `RandomRange100LT` en `PVCRALG.PAS`): generador congruencial lineal de 32 bits sembrado
     con `seed shl 16`, idéntico a `pvcr.pas`/`VcrPlayerPHost`. Validado comparando secuencias
     contra una referencia C++ extraída de `pvcralgorithm.cpp` (salidas idénticas).
     ✅ **Recarga portada** (`BeamRecharge`/`TorpsRecharge`/`FighterRecharge`): cada tick, lo
     que no está a tope (`<1000`) gana `RandomRange(rate)` con los `*_recharge` precalculados;
     notifica al visualizador (`updateBeam`/`updateLauncher`). El orden de llamadas al RNG
     (lo fija `playCycle`, bloque 6) es lo que conserva la bit-exactitud.
  3. Beams: `fireBeam` + aplicación de daño/escudo/tripulación (`hit`).
     ✅ **Modelo de daño portado y verificado bit-exacto** (`Hit` + `ComputeShieldDamageS`/
     `ComputeHullDamageS`/`ComputeCrewKilledS`, con las variantes Regular y Alternative de
     `pvcralgorithm.cpp`, modelo entero): golpea escudo, desborda a casco y mata tripulación
     sobre los valores escalados; validado contra una referencia C++ en ambos modos de combate
     (escudo, casco y tripulación — salidas idénticas). ✅ **`BeamFire`** (un beam por llamada:
     fighter o nave, gasto de carga, eventos `fireBeam`/`killFighter`), `BeamFindNearestFighter`
     y `GetDistance`. Detalle crítico replicado: el `missing` del path de fighter consume RNG
     aunque no haya fighter. `SetCapabilities` fija los flags del VCR (DeathRay/Beam).
  4. Torpedos (`fireTorpedo`).
     ✅ **`TorpsFire` portado**: dispara un torpedo por llamada desde el primer tubo cargado
     (`status>=1000`), gasta munición, tira `RandomRange100` y si `rr <= torp_hit_odds` aplica
     `Hit` (modelo ya verificado); `torp_kill`/`torp_damage` ya llevan el ×2 de no-AC del
     precálculo. Emite `updateLauncher`/`fireTorpedo`. Reusa piezas ya verificadas bit-exactas.
  5. Fighters (lanzar/mover/aterrizar/derribar, combate inter-fighter).
     ✅ **Portado**: `FighterLaunch` (uno por llamada desde una bahía cargada),
     `FighterMove` (atacantes hacia el enemigo; los que vuelven aterrizan al llegar a su nave),
     `FighterAttack` (golpea con `Hit` cuando está en rango; retirada si rebasó al enemigo) y
     `FighterIntercept` (combate inter-fighter). Este último **verificado bit-exacto** contra
     una referencia C++ (mismos fighters derribados y misma semilla final en los casos con
     match y degenerado), validando el hash de posición (`shr` lógico ≡ `>>` con signo de C
     para lo que importa), el emparejamiento por bins y el orden crítico de llamadas al RNG.
  6. `playCycle` (orquesta el turno de combate) + condición de fin + `doneBattle`
     (explosiones finales). ✅ **Portado y validado end-to-end**: `PlayCycle` ejecuta
     el turno en el orden exacto de PHost (recarga → lanzar → atacar/disparar → intercept
     → mover) con el cortocircuito del `or` replicado explícitamente; `CanStillFight`, el
     detector de inactividad (`CheckCombatActivity`, anti-bucle-infinito), `MoveObjects`,
     y `DoneBattle` (des-escalar, aterrizar fighters supervivientes, fijar resultado y
     `killObject`), con `BattleResult` expuesto. **Batalla completa verificada bit-exacta**
     contra una réplica C++ del algoritmo entero en 3 escenarios (combate regular,
     combate alternativo `scale=mass+1`, y nave-vs-planeta): mismo nº de ticks, mismo
     estado final de ambos objetos y **misma semilla final** en los tres. La verificación
     destapó que los campos escalados (`max_scaled`, `damage_limit_scaled`) exceden 16 bits
     en modo alternativo y exigen `longint` — ya estaban correctamente declarados así en
     `TFixedStatus`/`TRunningStatus`.
- **Bonus raciales de combate** (revisado contra la documentación de PHost 4.1h,
  `formulas.html`/`config.html`/`rules.html`) — se aplican por tres vías, todas cubiertas:
  - *Config per-jugador* (recarga de beams de la Fed, scalings, etc.): el algoritmo indexa
    cada opción por el **dueño** del combatiente (`EMV(CombatCfg.X, owner, …)`), igual que
    PCC2ng. ✅
  - *Rama por raza en el algoritmo*: solo el **Lizard** (raza 2) con su 150% de daño antes de
    estallar (`PlayerRace(owner)=2`). ✅
  - *Horneado en el registro VCR por el host*: masa +50kt, +3 bahías, escudos y `FullWeaponry`
    de la **Federación** (`AllowFedCombatBonus`) — `MapVCR` los lee tal cual; el cargador de
    VCR de PCC2ng tampoco los re-aplica. ✅
  - **Privateers (raza 5): ×3 al `Kill_Power` de los beams.** No va por `CrewKillScaling` sino
    por un factor que PCC2ng fija al cargar el VCR (`database.cpp:87`:
    `setBeamKillRate(PlayerRace[owner]==5 ? 3 : 1)`) y el algoritmo usa en `fireBeam`. Portado
    con un campo `beam_kill_rate` en `TFixedStatus`, fijado en `InitBattle` y usado en
    `BeamFire`; afecta a tripulación **y** a escudo (el `kill` alimenta ambas fórmulas en
    `Hit`). **Validado bit-exacto** con un combatiente Privateer (escenario E4: R muere por
    tripulación arrasada en vez de por daño, y desaparece el bonus → cambia el combate). Los
    otros cuatro *rates* (`BeamChargeRate`, `TorpMissRate`, `TorpChargeRate`, `CrewDefenseRate`)
    coinciden con `database.cpp` y quedan como constantes. ✅
  - *Silent fixes de `checkSide` (`database.cpp`)*: ✅ portados en `MapSide` (si `beamType=0` →
    `numBeams=0`; si `torpType=0` → `numLaunchers=0`/`numTorps=0`; planeta con tubos desempaqueta
    la munición). No eran la causa de la discrepancia, pero quedan fieles a PCC2ng.
- **Fase C — Conectar el visualizador a `TCOMBAT`:** ✅ *hecha.* Implementados los 8 eventos
  con las primitivas de dibujo de VPA, con el *timing*/animación de VPA y un modo "sin animación".
  - **Decisión de diseño (importante):** se usan **solo las primitivas puras de dibujo**
    (`Beam`, `Torpedo`, `Fighter`, `Blast`, `Gauge`, `DrawShield`), **no** las rutinas de alto
    nivel `Hit`/`FireBeam`/`FireTorpedo`/`Battle`, porque esas **llevan dentro la matemática de
    THost** (p.ej. `Hit` recalcula escudo/daño/tripulación con la fórmula clásica). El visor PHost
    debe **renderizar el estado real de PVCRALG**, no recalcular nada.
  - **C1 ✅ (hecho):** PVCRALG expone *accessors* de solo lectura para que el visor consulte la
    geometría y el estado en vivo: `VcrObjectX`, `VcrFighterX`, `VcrFighterStatus`,
    `VcrActiveFighters`, `VcrBeamStatus`, `VcrLauncherStatus`, `VcrCurShield/Damage/Crew`
    (des-escalado en vivo), `VcrObjInfo`, `VcrDistance`, `VcrTime`. Los 8 callbacks ya estaban
    cableados en las funciones de disparo desde la Fase B. Son lecturas puras: no tocan la
    matemática (bit-exactitud intacta).
  - **C2 ✅ (hecho):** mapeo de coordenadas derivado y verificado. Es **lineal, 100 metros por
    píxel**: `pantalla_X = 320 + objectX/100`. El algoritmo usa `m_objectX` en `±29000` m
    (standoff 3000 m); la pantalla, `SX[Left]=30 … SX[Right]=610` (centro 320, standoff 30 px).
    La proporción coincide (58000/3000 = 580/30), así que el mapeo es exacto para nave-vs-nave.
    Los fighters usan el mismo mapeo (`fighterX/100`).
  - **C3 ✅ (hecho):** los 8 callbacks implementados en `TCOMBAT.PAS` (`pvStartFighter`,
    `pvLandFighter`, `pvKillFighter`, `pvFireBeam`, `pvFireTorpedo`, `pvKillObject`;
    `updateBeam`/`updateLauncher` quedan a `nil` — indicadores de carga diferidos). Leen el
    estado real por accessors y dibujan con las primitivas puras; los gauges animan el barrido
    `viejo→nuevo` reusando los globales `shld/dam/crew/tf` como "último valor mostrado".
  - **C4 ✅ (hecho):** driver `CombatPHost` (mismo setup que `Combat` → `MapVCR` →
    `SetCapabilities`/`SetPhost3` → `InitBattle` → bucle `while PlayCycle` con `pvUpdateShips`/
    `pvUpdateFighters` + `Delay` + teclas → `DoneBattle` → vuelca resultados al VCR). **Compila y
    enlaza** (build verde).
  - **Salvedades de la Fase C (✅ pulidas después):** movimiento del sprite de nave contra un
    planeta — **corregido**: `pvUpdateShips` limita la posición de dibujo para que la nave no
    se meta dentro del disco (clamp anti-solape, sin tocar la distancia real mostrada);
    `pvKillObject` — **corregido**: ahora el driver dibuja la explosión completa con el sprite
    `ExplPic` (encima de todo, tras los refrescos, quitando antes el escudo), no un `Blast`
    simple; estelas de fighters — **corregidas** en la Fase E (array `pvFH`, borra cada caza con
    la misma forma con la que se dibujó). El **escalonado en Y de los fighters sigue siendo
    aproximado** (no confirmado como pulido). `SetPhost3` fijado a `False` en esta fase (la
    detección PHost 3-vs-4 es de la Fase D, que lo corrige a `True`). **Verificado
    visualmente** contra `PVCR.EXE` en la Fase E.
- **Fase D — Integración en VPA:** ✅ *hecho.* El visor PHost nativo está enrutado en
  `MESSAGES.PAS`:
  - **`ViewVCR`** (ver una batalla): en **PHost** (`pvcr`) llama a `CombatPHost(vcr,Yes,…)`
    (algoritmo portado, animado) en vez de construir el fichero temporal y `Exec(PVCR.EXE)`;
    en **THost** mantiene el `Combat` clásico. Toda la maquinaria de `PVCR.EXE` (temp file,
    rename, `Exec`, `SwapVectors`) **eliminada**.
  - **`GetVCRMessage`** (resumen del mensaje): PHost ya **no** sale antes de calcular; corre
    `CombatPHost(vcr,No,…)` sin animación para obtener el desenlace y mostrar los rótulos
    `/Destroyed/`/`/Captured/`, igual que THost. (Para eso `CombatPHost` vuelca el resultado a
    `dd[lr].pic` con `ExplPic`/`SurrPic`.)
  - **Tecla *View*** habilitada para PHost siempre (se quitó el requisito `pvcrexe`), y eliminado
    el aviso obsoleto *"Copy PVCR.EXE…"*.
  - **CRÍTICO (race vs owner):** el camino PHost pasa el `vcr` **crudo** (sin la conversión
    `dd[lr].race := Race[…]` que sí hace THost antes de `Combat`). `MapVCR` pone `owner := race`
    (slot de jugador) y **PVCRALG aplica `Race[]` internamente** vía `PlayerRace(owner)`;
    pre-convertir causaría doble conversión (`Race[Race[slot]]`).
  - **`SetPhost3(True)`** (no `False`): el nombre engaña — `pvcralgorithm.hpp` documenta
    `false=PHost 2.x, true=PHost 3.x/4.x`. PHost 3 y 4 usan la misma rama (`true`); solo el
    obsoleto PHost 2.x usaría `false`. Correcto para la partida 4.1h de Pablo.
  - Build verde; arranca bajo Xvfb. **Verificación visual completada** (ver Fase E).
  - **Simulador de combate (F5) enrutado** (`VCS.PAS`): el simulador de VPA construye un
    `VCRData` en memoria y hasta ahora **siempre** llamaba al `Combat` clásico (matemática de
    THost), aunque la partida fuese PHost. Ahora enruta igual que el visor: en **PHost**
    (`if PHOST then`) usa `CombatPHost` (la matemática PHost portada de PCC2ng, ya validada
    bit-exacta); en **THost**, el `Combat` clásico. El *Anti-LeftWin* (heurística de THost que
    suma 360 de masa al lado derecho para compensar el sesgo de victoria del lado izquierdo) se
    **salta en PHost** —el combate PHost es por masa y ese `+360` lo falsearía— (de hecho ya
    estaba desactivado para PHost vía `VCSet bit 4`; el `not PHOST` explícito lo documenta). Las
    naves del simulador son de nivel 0 (no hay interfaz para fijar experiencia), así que se pone
    `VcrFileCaps:=0` → combate PHost **base**, sin línea de rango. Como `CombatPHost` vuelca el
    resultado final a `dd[lr]`/`shld[lr]` igual que `Combat`, el resumen del simulador
    (`WriteResult`) muestra el desenlace PHost correctamente.
- **Fase E — Validación (crítica):** ✅ *hecha.* Validado **bit-exacto contra `PVCR.EXE`**
  (DOSBox) sobre combates reales de la partida PHOENIX4 (PHost 4.1h), comparando fotograma a
  fotograma de un vídeo: ganador, daño final, supervivientes, munición, escudo/tripa y cuenta
  de cazas coinciden (p. ej. combate 2: nave Crystalline vs planeta Empire → la nave gana con
  65 torpedos, el planeta muere con 18 cazas en reserva; escudo nave 9.8, tripa 1035).
  - **Causa raíz encontrada y corregida:** los combates de portaaviones/planeta salían
    *invertidos* respecto a `PVCR.EXE` **no** por la matemática, sino porque VPA no abría
    `pconfig.src` (minúsculas) en Linux → usaba config por defecto con `AllowAlternativeCombat=No`.
    Resuelto con `ResolveCase` (ver Fase 5). Con la config real cargada, el resultado coincide.
  - **Banco de pruebas reproducible** (`/tmp/t2/*.pas`): arneses que ejecutan el `PVCRALG` real
    sobre `VCR7.DAT` cargando `beamspec.dat`/`torpspec.dat`, con tabla 4-vías (config×altcombat)
    que aísla la variable decisiva, y un paso a paso por `PlayCycle` que imprime reserva/vuelo de
    cazas a cada distancia para el cotejo con los fotogramas.
  - **Cazas en reserva:** el contador muestra **solo** los cazas en bahía (`numFighters`), no los
    que están en vuelo, igual que `PVCR.EXE` (verificado: 21 en reserva a 35600 m, no 51).
  - **Estelas de cazas:** corregido el borrado (cada caza se borra con la misma forma `h` con que
    se dibujó, vía `pvFH`); ya no deja rastro al moverse.
- **Fase F — Niveles de experiencia (PHost 4.x)** — ✅ **COMPLETADA y validada bit-exacta.**
  En PHost 4 cada unidad (nave o planeta) tiene un **nivel de experiencia** (0..`NumExperienceLevels`,
  con `NumExperienceLevels` entre 0 y 10). El nivel modifica el combate: las opciones de config se
  ajustan con los **modificadores `EMod*`** según la fórmula de PCC2ng
  (`getExperienceModifiedValue`): `valor_efectivo = clamp(base[jugador] + EMod[nivel], min, max)`,
  aplicada a ~20 parámetros (`BeamHitOdds`/`Bonus`, recargas de beam/tube/bay, `ShieldDamage`/
  `ShieldKillScaling`, `HullDamageScaling`, `CrewKillScaling`, `MaxFightersLaunched`,
  `StrikesPerFighter`, `Fighter*`, `BeamHitFighterCharge`).
  - **Parser** (`CONFIG.PAS`): helper `GetEMod` que captura las 20 claves `EMod*` **por nivel**
    (admite tanto listas `4,4,5,8` como valor único `0`, que se propaga a todos los niveles);
    defaults a 0. `NumExperienceLevels` ya se leía.
  - **Datos** (`VPADATA.PAS`): tipo `EArr = array[1..10] of int` y campos `EMod*` en `TCombatCfg`.
  - **Algoritmo** (`PVCRALG.PAS`): el nivel de cada unidad ya se leía del registro VCR
    (`experienceLevel` en el offset 33 del objeto, tras `numBeams`). `EMV` ahora suma el
    `EMod[nivel]` de la unidad; se añade el **reset de consistencia** de PCC2ng: si el fichero no
    declara `ExperienceCapability` o el nivel supera `NumExperienceLevels`, la unidad pasa a nivel 0.
  - **Capabilities del fichero (bug sutil corregido)** (`MESSAGES.PAS` + `TCOMBAT.PAS`): siguiendo
    `classicvcr.cc`, las capabilities (DeathRay/Experience/Beam) se determinan **una sola vez a
    partir del primer registro** del fichero VCR —`(firstFlags & 0x8000) ? firstFlags & ~0x8000 : 0`—
    y valen para **todos** los combates. En un fichero PHost real solo el 1er registro lleva el bit
    `ValidCapabilities` (0x8000); los demás llevan flags = 0. Antes el visor usaba las flags
    **por-registro**, lo que **desactivaba la experiencia en los combates 2º en adelante**. Ahora
    `GetVCR` calcula `VcrFileCaps` del registro #1 y el visor lo usa.
  - **Validación:** bit-exacta contra el test **`pvcr-exp` de PCC2** (6/6 combates, con unidades de
    nivel 2 y 3), ejercitando el stack completo: parser real de `pconfig.src` → `EMod` → combate con
    experiencia. Coinciden tiempo de fin, ganador y escudo/daño/tripulación/munición finales. Verificado
    también que el parser lee correctamente el `pconfig.src` de una partida real (NORTH12,
    `NumExperienceLevels=4`) y **sin regresión** en combate sin experiencia (PHOENIX4).
  - **Nombre del rango en el visor — ✅ hecho.** El visor muestra `Rank : `+ el nombre del
    rango (`ExperienceLevelName(ex)`, parseado de `ExperienceLevelNames` en `pconfig.src`),
    solo si el fichero VCR declara `ExperienceCapability`, con el mismo reset de consistencia
    que el resto de la Fase F (nivel fuera de rango → 0).
  - *(Pendiente/opcional: death rays y el combate multi-nave **FLAK** (`game/vcr/flak/` de
    PCC2ng). Sin fecha; no bloquean el resto del visor.)*

> **Estado:** ✅ **funcional y validado bit-exacto contra `PVCR.EXE`.** El visor PHost nativo
> sustituye por completo a `PVCR.EXE`: mismo desarrollo, mismos contadores fotograma a fotograma
> y mismo desenlace. Quedan solo retoques estéticos (ver *Limitaciones*). Stefan Reuther queda
> disponible para dudas de detalle del algoritmo.

### Estado actual (runtime)

El binario nativo **funciona y es jugable**. Resueltos, en orden, los problemas que
hacían parecer que el programa estaba "congelado":

1. **Foco de teclado** — bajo gestores de ventanas tipo Cinnamon, `ptc` no pedía el foco
   de teclado al abrir. Unit nueva **`xfocus`**: busca la ventana por título y hace
   `XSetInputFocus` + `_NET_ACTIVE_WINDOW`. Teclado 100% operativo.
2. **Fichero de ayuda** — el `VPA.HLP` original era binario de DOS (empaquetado de
   registros de Borland ≠ FPC). Se regenera desde `VHLP/VPA.HHH` con **`make hlp`** (usa
   `xvfb-run` porque el compilador de ayuda enlaza la capa gráfica). Hay que copiar el
   `VPA.HLP` resultante a la carpeta de partida.
3. **Ratón no habilitado** — `MousePresent` quedaba en `False` (la detección INT33 de DOS
   se quitó). Por defecto a `True` en Linux (`/K` lo sigue desactivando).
4. **Scroll desbocado** — el bucle de scroll dependía de la interrupción de ratón de DOS.
   Ahora sondea el ratón en cada vuelta y no hace scroll si el puntero sale de la ventana
   (`xfocus.PointerInsideWindow` vía `XQueryPointer`).
5. **CPU al 100% / ventilador** — el bucle principal hacía *busy-wait* (sin SO al que ceder
   en DOS). Añadido `Keyboard.CpuNap` (sleep de ~5 ms) en el bucle inactivo y en el scroll
   continuo. Consumo en reposo ~0%.
6. **Cursor del sistema** — se dejó visible y con comportamiento normal dentro/fuera de la
   ventana (el ocultado anterior lo hacía desaparecer fuera).
7. **Ventana escalable y pantalla completa** — `VPA_SCALE` agranda la ventana (la superficie
   sigue siendo 640×480 y `ptc` la escala) y `VPA_SCALE=fullscreen` ocupa toda la pantalla por
   encima del panel del escritorio, **sin** cambiar el modo de vídeo. El ratón se reescala en
   ambos sentidos para mantener la precisión píxel a píxel (ver §1 y §4).
8. **Sprites de naves/combate** — portado el decodificador de sprites VGA planares (4 planos) +
   paleta + truncado + rotación + espejo, montando la imagen en formato `ptcgraph`. Muestran las
   naves correctamente el **simulador de combate** (ambos bandos, con color y animación), las
   **StarBases** (pantalla de construcción) y el salvapantallas. La paleta del juego se
   salva/restaura alrededor del combate para no alterar los colores del mapa.
9. **Salida con/sin guardar** — **Alt-X** y el botón **[X]** de la ventana salen **guardando**;
   **Ctrl-Alt-X** sale **sin guardar** tras pedir confirmación (Y/N). La intención se fija de
   forma determinista en la propia pulsación (no se lee el estado de modificadores al cerrar).
10. **Ratón quieto al cargar** — al abrir, el cursor se centra y la posición interna de
   `ptcmouse` se sincroniza con el *warp*, de modo que el mapa ya no hace auto-scroll solo hasta
   que el usuario mueve el ratón.
11. **Crash al comprar torpedos/cazas** — al entrar en «Buy torps/fighters» de una StarBase el
   programa abortaba con `RunError(250)` («NOT ENOUGH MEMORY»). Causa: el menú reserva un buffer
   para guardar la pantalla de debajo (`MenuSize`→`ImageSize`), y en 256 colores (`D8bit`) ese
   buffer pesa ~2 bytes/píxel — mucho más que los 16 colores planares de la BGI de DOS —, así que
   superaba el límite `ReservedMemory=30000` que comprueba `UnLockReservedMemory`. Medido: la
   región de ese menú da 30438 bytes. Subido `ReservedMemory` a **65536** (los buffers de pantalla
   se guardan en un `word`, ≤65535, así que 64 KB los cubre todos; en Linux reservarlos es gratis).
12. **Modificadores Shift/Ctrl/Alt** — `KbdFlags` consulta ahora el estado **actual** de los
   modificadores a X11 (`XQueryPointer`, como la BIOS DOS `0040:0017`), de modo que funcionan tanto
   los atajos de teclado (Shift/Ctrl+flecha…) como **ratón+modificador** (p. ej. el zoom del mapa
   con Shift/Ctrl y el botón central). Además, el `ptccrt` vendorizado ahora emite **Alt+flecha**
   (`$9B00`/`$9D00`/`$A000`/`$9800`) también en modo `kmTP7` —el que usa VPA—, no solo en
   `kmGO32/kmFPWINCRT`; antes se tragaban y no llegaban el paneo del mapa ni los ajustes ±100.
   Todo validado por inyección de eventos bajo Xvfb.
13. **Diana blanca propia (cursor)** — VPA muestra su **cruz blanca** original como cursor,
   en lugar del puntero del sistema. Se implementa en el `ptc` vendorizado
   (`x11/x11windowdisplayi.inc`): su cursor "visible" pasa a ser una cruz blanca (misma forma
   que el `CrossPointer`/`MouseMotionHandler` originales, **simétrica**), fijada **por-ventana**
   sobre la propia ventana de ptc (`XChangeWindowAttributes`/`CWCursor`) — igual mecanismo que
   el cursor invisible que ptc ya usaba —, de modo que **solo se ve dentro de VPA** y el
   escritorio recupera su puntero al salir. Se hace en ptc (y no en `xfocus` con `XDefineCursor`)
   porque ptc reponía el cursor a `None` en cada `ShowMouse` y pisaba cualquier `XDefineCursor`
   externo. La diana se **auto-escala** a la escala de la ventana (`AWidth/640`, nearest-neighbor,
   cap 4×) para verse del tamaño correcto a 2×/pantalla completa (el cursor X va a píxeles nativos,
   no lo escala ptc con el contenido). Además, el warp del cursor (`MapSurfaceToWindow`) se centra
   en el bloque escalado (no en la esquina) para que la cruz caiga centrada sobre planetas/objetos.
   Nota: la diana real de VPA es **simétrica**; la ligera asimetría que se ve en DOSBox no está en
   el cursor sino que la introduce el escalador de DOSBox (a menudo estirando a 16:9), así que no se
   reproduce — se prioriza la fidelidad al cursor original.

### Limitaciones conocidas

| Tema | Estado | Detalle |
|---|---|---|
| Decimales del combate | 🔒 Por diseño (asumido) | El visor muestra escudo/daño/tripa con un decimal (como `PVCR.EXE`) y la **parte entera coincide** (p. ej. escudo 9.8). El primer decimal puede diferir ~±0.5: `PVCR.EXE` acumula la fracción sub-unidad distinto a PCC2ng (coinciden en los cruces enteros — de ahí la bit-exactitud del **resultado** — pero no en la fracción). Igualar el decimal exacto exigiría abandonar el algoritmo fiel a PCC2ng, así que **se deja así a propósito**: se prioriza respetar al 100% el código portado y se muestra el valor correcto del algoritmo. |

### Fuentes de mapa de bits (`.FNT`)

VPA admite `Font=fichero.fnt` en la sección `[System]` de `vpa.ini` para cargar una fuente
de mapa de bits **8×16** (256 caracteres × 16 bytes = 4096 bytes) en su buffer interno
`StandardFont` (la que usa `WriteXY`). La distribución oficial incluye `LATIN1.FNT` (Latin-1,
ideal para Linux), `SANSERIF.FNT`, `THIN.FNT` y varias *code pages* DOS. **Ojo:** esto **no**
afecta a los nombres de planeta del mapa, que usan la fuente vectorial (`OutTextXY`).
