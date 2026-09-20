# WAYLAND.md — Hoja de ruta para Wayland nativo en VPA-Linux

Documento de trabajo interno del port. Está escrito **solo en español** y no
tiene traducción al inglés: no es documentación de usuario, es el plan de obra
que seguimos sesión a sesión.

- **Objetivo del documento:** que en cualquier momento se pueda abrir este
  fichero, mirar la primera casilla sin marcar y saber exactamente qué toca
  hacer, con qué criterio se da por hecho y qué no hay que tocar todavía.
- **Alcance:** desde el estado actual (`ptcgraph` → PTCPas → X11, enlazado
  estáticamente dentro del binario) hasta un `VPA` que abre ventana en una
  sesión Wayland sin `DISPLAY` y sin XWayland.
- **Base:** VPA-Linux 3.67.6, rama `main`, Free Pascal 3.2.2.

---

## 0. Cómo usar este documento

### 0.1 Convenciones

- Cada tarea tiene un **identificador estable** (`T3.4`, `T8B.2`…). Los
  identificadores no se reutilizan ni se renumeran aunque se inserten tareas
  nuevas: si hace falta meter una tarea entre `T3.4` y `T3.5`, se llama
  `T3.4b`. Así podemos decir «esta sesión hacemos T5.1 a T5.4» y que siga
  significando lo mismo dentro de seis meses.
- Estado de una tarea:
  - `- [ ]` pendiente
  - `- [x]` hecha (se añade al final el hash corto del commit: `— a1b2c3d`)
  - `- [~]` en curso / bloqueada (se explica debajo en una línea)
  - `- [-]` descartada (se explica por qué; **no se borra**, el descarte es
    información)
- Estado de una fase en la tabla de 0.3: `☐` pendiente, `◐` en curso,
  `☑` cerrada (con todos sus criterios de aceptación verificados).
- Cada **fase** termina con un bloque **Criterio de aceptación**. Una fase no
  se cierra si alguno de sus criterios falla, aunque todas sus casillas estén
  marcadas.
- Las fases marcadas con 🔒 **no se pueden empezar** hasta cerrar la anterior.
  Las marcadas con ⚡ se pueden adelantar en paralelo si apetece.

### 0.2 Reglas de trabajo heredadas del proyecto

Estas reglas no se negocian durante la migración, y precisamente aquí es donde
más fácil es saltárselas:

1. **Un commit por cambio lógico.** `git add <fichero-concreto>`, nunca
   `git add .`.
2. **Sin parches provisionales.** Nada de segundos caminos de código «hasta
   que funcione Wayland». Si algo no se puede hacer limpio todavía, se deja sin
   hacer y se anota aquí.
3. **Los fuentes Pascal son ASCII.** Los comentarios van en español pero sin
   acentos ni eñes. Este `.md` sí es UTF-8 con finales de línea LF.
4. **Verificación antes de cerrar cualquier tarea:** `make build` limpio, sin
   avisos nuevos, y arranque comprobado con `xvfb-run`.
5. **El camino X11 no puede empeorar nunca.** En todo momento de la migración,
   `VPA` tiene que seguir siendo jugable en X11 exactamente igual que hoy. Si
   una fase intermedia rompe X11, esa fase está mal planteada.

### 0.3 Estado global

| Fase | Título | Estado |
|------|--------|--------|
| 0 | Preparación y red de seguridad | ☑ cerrada (2026-09-13) |
| 1 | Inventario de la frontera gráfica | ☑ cerrada (2026-09-13) |
| 2 | Definición de la ABI v1 | ☑ cerrada (2026-09-13) |
| 3 | Cargador dinámico | ☑ cerrada (2026-09-15) |
| 4 | Detección y selección de backend | ☑ cerrada (2026-09-15) |
| 5 | Plugin X11 (gráficos, ventana, teclado, ratón) | ☑ cerrada (2026-09-16) |
| 6 | Migración de VPA-Linux a `VPAGraph` | ☑ cerrada (2026-09-19) |
| 7 | Decisión: motor de dibujo del plugin Wayland | ☑ cerrada (2026-09-19) — **vía B** |
| 8 | Motor de dibujo Wayland (vía B) | ☑ cerrada (2026-09-20): 0 diferencias (`make wayland-test`), doradas 20/20 |
| 9 | Eventos: teclado, ratón y cierre de ventana | ☑ cerrada (2026-09-20): T9.1–T9.8 hechas y probadas (`make wayland-input-test` y pruebas manuales de Pablo en KWin 6.7.5); el teclado numérico sin BloqNum resultó ser el ratón absoluto de la VM (R12), no VPA |
| 10 | Escalado, HiDPI y pantalla completa | ✅ cerrada (2026-09-20): probada por Pablo en KWin (VM Slackware) a 800×600, 1920×1080 y 2048×1152, con KDE al 100 %, 150 % y 200 % (D-25 a D-29) |
| 11 | Comparación visual automatizada | ☑ cerrada (2026-09-20): `make visual-test`, 21 escenas × 2 backends = 42 de 42 idénticas a las doradas, umbral cero |
| 12 | Empaquetado, documentación y release | ☐ |

---

## 1. Objetivo y alcance

### 1.1 Qué se persigue

- Que `VPA` funcione en una sesión Wayland **sin XWayland**: sin `DISPLAY`, sin
  `libX11` cargada en el proceso.
- Mantener `ptcgraph`/PTCPas como backend estable y por defecto en X11, sin
  tocar su comportamiento.
- **Un único ejecutable.** Nada de `vpa-x11` y `vpa-wayland`.
- Cargar en cada sesión **solo** el backend que se va a usar, de forma que la
  ausencia del otro no impida arrancar.
- Contrato binario (ABI) estable, versionado y verificable entre el ejecutable
  y los plugins.
- Dejar la puerta abierta a backends futuros (KMS/DRM, framebuffer, lo que
  venga) sin tocar el núcleo del programa.

### 1.2 Qué **no** se persigue (no-objetivos)

Conviene escribirlo porque la tentación de ampliar el alcance en mitad de la
obra es enorme:

- **No** se cambia la resolución lógica. VPA sigue siendo 640×480 en 256
  colores (`D8bit` / `m640x480`). Todo lo demás es escalado de presentación.
- **No** se moderniza la interfaz ni se añaden funciones de juego.
- **No** se retira `ptcgraph` del proyecto. En el resultado final sigue vivo,
  dentro del plugin X11.
- **No** se toca el formato de los ficheros de partida ni nada de `CC/`.
- **No** se busca portar a Windows ni a macOS, aunque la arquitectura lo
  facilite.
- **No** se cambia el sistema de compilación por CMake, Lazarus ni nada
  similar. Seguimos con `Makefile` + `vpa.cfg` + `fpc`.

### 1.3 Criterio de éxito final

El proyecto está terminado cuando, en la máquina de desarrollo y en al menos
una máquina de pruebas independiente:

```bash
readelf -d build/VPA | grep -E 'libX11|libSDL|libwayland'   # sin resultados
env -u DISPLAY VPA_GRAPH_BACKEND=wayland ./build/VPA 3 ~/PLANETS
```

abre la ventana, dibuja el mapa estelar, responde a teclado y ratón, permite
jugar un turno completo y guardarlo, y el resultado visual es indistinguible
del backend X11 salvo diferencias justificadas y documentadas.

---

## 2. Punto de partida: cómo está hoy el acoplamiento

Esta sección es el diagnóstico sobre el que se apoya todo el plan. Los números
salen de inspeccionar `main` en la versión 3.67.6.

### 2.1 No hay una frontera gráfica, hay cuatro

El documento de partida asumía que la frontera era `ptcgraph`. En realidad el
ejecutable toca el sistema de ventanas por **cuatro sitios distintos**, y si
solo se abstrae el primero, `VPA` **seguirá enlazando `libX11` directamente** y
no habremos conseguido nada:

| # | Frontera | Vía | Consumidores |
|---|----------|-----|--------------|
| 1 | `ptcgraph` — API BGI/Graph | `uses ptcgraph` en 24 unidades | todo el dibujo |
| 2 | `ptccrt` — teclado | `UNIT/KEYBOARD.PAS` | `ReadKey`, `KeyPressed`, `PTCLastKbdFlags`, `PTCQuitNoSave` |
| 3 | `ptcmouse` — ratón | `UNIT/MOUSE.PAS` | `ShowMouse`, `HideMouse`, `GetMouseState`, `SetMousePos` |
| 4 | `xfocus` — **Xlib directo** | `UNIT/xfocus.pas` | foco, cursor, escala, pantalla completa, mapeo de coordenadas |

La cuarta es la que rompe el plan original. `UNIT/xfocus.pas` hace
`uses x, xlib, xutil, xatom` y mantiene una **conexión X persistente propia**,
paralela a la de PTC. Tiene 19 puntos de llamada repartidos en seis ficheros:

| Función de `xfocus` | Llamada desde |
|---------------------|---------------|
| `ResolveScale` | `VPA/VPAINIT.PAS:1339` |
| `GrabInputFocus` | `VPA/VPAINIT.PAS:1812`, `VPA/INI.PAS:348`, `VPA/INI.PAS:410` |
| `ApplyWindowScale` | `VPA/VPAINIT.PAS:1813`, `VPA/INI.PAS:349`, `VPA/INI.PAS:411` |
| `WantFullscreen` + `RequestFullscreen` | `VPA/VPAINIT.PAS:1814`, `VPA/INI.PAS:350`, `VPA/INI.PAS:412` |
| `ReleaseFullscreen` | `VPA/SCREEN.PAS:288` |
| `PointerInsideWindow` | `VPA/VPA2.PAS:4078` |
| `MapSurfaceToWindow` | `UNIT/MOUSE.PAS:155` |
| `MapMouseToSurface` | `UNIT/MOUSE.PAS:178` |
| `XReady`, `KbdModifiers` | `UNIT/KEYBOARD.PAS:83-84` |

**Consecuencia para la hoja de ruta:** la ABI no es «una tabla de primitivas
gráficas», es el contrato completo de *backend de ventana*: dibujo + ventana +
foco + escala + teclado + ratón. Esto está incorporado a las fases 2 y 5.

### 2.2 Inventario preliminar de la API Graph

Conteo bruto sobre `VPA/`, `UNIT/`, `CC/`, `VHLP/` (incluye comentarios, así que
son cotas superiores; la Fase 1 produce el inventario fino).

> **Superada.** El inventario fino está en `docs/vpagraph-api-inventory.md`
> (Fase 1). Difiere de esta tabla en dos cosas que conviene saber al leerla:
> solo cuenta el código que el ejecutable **enlaza** (ni `CC/`, ni `TASKS`,
> ni `DETAILS`, ni las utilidades `VHLP*`), y no cuenta las variables locales
> que se llaman como una primitiva (`line` en `EXTFEAT`/`VPA4`). Con eso,
> `Line` baja de 397 a 270, `ReadKey`/`KeyPressed` de `ptccrt` se usan solo
> desde `KEYBOARD.PAS`, y `TextWidth`, `RegisterBGIDriver`, `GraphErrorMsg` y
> `Detect` salen de la v1. La tabla se conserva como registro del punto de
> partida.

| Símbolo | Usos | Ficheros | Símbolo | Usos | Ficheros |
|---------|-----:|---------:|---------|-----:|---------:|
| `OutTextXY` | 1195 | 20 | `PutImage` | 41 | 9 |
| `SetColor` | 706 | 20 | `PutPixel` | 39 | 6 |
| `Line` | 397 | 27 | `SetWriteMode` | 36 | 8 |
| `SetLineStyle` | 81 | 17 | `SetViewPort` | 32 | 3 |
| `Bar` | 31 | 12 | `SetTextJustify` | 31 | 10 |
| `Rectangle` | 27 | 17 | `SetFillStyle` | 20 | 11 |
| `Circle` | 19 | 10 | `SetGraphMode` | 19 | 7 |
| `ClearDevice` | 17 | 7 | `MoveTo` | 15 | 4 |
| `SetTextStyle` | 12 | 5 | `RestoreCrtMode` | 12 | 6 |
| `GetGraphMode` | 10 | 6 | `LineTo` / `LineRel` | 9 / 9 | 4 / 3 |
| `ImageSize` | 8 | 5 | `SetRGBPalette` | 7 | 1 |
| `GetImage` | 6 | 4 | `GetViewSettings` | 6 | 3 |
| `CloseGraph` | 5 | 4 | `GraphResult`/`GraphErrorMsg` | 5 / 5 | 3 / 3 |
| `GetPixel` | 4 | 1 | `TextWidth` | 4 | 1 |
| `InitGraph` | 4 | 4 | `HLine` | 2 | 1 |
| `RegisterBGIDriver` | 2 | 2 | `Ellipse`, `GetColor`, `ClearViewPort`, `GetRGBPalette`, `InstallUserFont` | 1 | 1 |

Lecturas importantes de esta tabla:

- El grueso son **cuatro llamadas**: `OutTextXY`, `SetColor`, `Line` y
  `SetLineStyle`. Si esas cuatro no son perfectas, no hay proyecto.
- **No aparecen** `Arc`, `PieSlice`, `FillPoly`, `FloodFill`, `DrawPoly`,
  `Sector`, `Bar3D`, `FillEllipse`, `SetActivePage`, `SetVisualPage`,
  `GetArcCoords`, `SetUserCharSize`. La hoja de ruta original reservaba etapas
  enteras para implementarlas: **no hacen falta en la ABI v1**, y meterlas es
  trabajo puro de escaparate. Van a la lista de «solo si aparecen».
- **Nadie reasigna los punteros de función** de `graph` (`PutPixel := @...`).
  Comprobado: no hay ni una asignación. Eso permite usar una tabla de funciones
  fija sin romper nada.

### 2.3 Restricciones heredadas que condicionan el diseño

Cada una de estas ha costado sangre en el port y cualquiera de ellas puede
hundir la migración si se descubre tarde:

1. **El programa compila en modo Turbo Pascal (`-Mtp`)**, con las
   comprobaciones de runtime desactivadas (`-Ci- -Cr- -Co- -Ct-`). La unidad
   pública `VPAGraph` tiene que ser consumible desde `-Mtp`. Precedente que
   demuestra que se puede: `VENDOR/ptcgraph.pp` declara `{$mode objfpc}` de
   forma local y `VPA` la usa sin problema.
2. **`OutTextXY` recibe un `string` de Pascal** (shortstring en `-Mtp`), y hay
   1195 llamadas. Un shortstring **no puede cruzar la ABI**. La conversión a
   `PAnsiChar` se hace en el envoltorio, no en los 1195 sitios.
3. **El formato de imagen de `ptcgraph` es parte del contrato, no un detalle.**
   `VPA/TCOMBAT.PAS` y `VPA/EXTFEAT.PAS` **construyen buffers de imagen a mano**
   (`ImgSize = 12 + 104*104*2`, cabecera de 3 `longint` y un `word` por píxel) y
   se los pasan a `PutImage`. Cualquier backend nuevo tiene que aceptar
   exactamente ese diseño de memoria. No es negociable.
4. **`ImageSize` devuelve `longint`, no `word`.** Ya costó una corrupción de
   heap en 3.67.5 (`MenuSize`/`ChooseMenu`). En la ABI, todo tamaño de imagen
   es de 32 bits como mínimo.
5. **`SetWriteMode(XORPut)`** se usa en 36 sitios (gomas elásticas, cursores,
   selección). Es la primitiva más fácil de implementar «casi bien» y la más
   visible cuando está mal.
6. **La fuente vectorial `LITT_VPA.CHR`** se carga con
   `InstallUserFont('LITT_VPA.CHR')` (`VPA/VPAINIT.PAS:1347`) y se usa como
   `LittFont` en las etiquetas del mapa. Hay además `DefaultFont` (bitmap 8×8)
   y la fuente rusa vía `VPA/RUSFONT.INC`. Un backend nuevo necesita rasterizar
   `.CHR` con **métricas idénticas**, o el texto del mapa se descuadra.
7. **`cthreads` va primero en el `uses` de `VPA/VPA.PAS`** porque `ptcgraph`
   usa hilos para el bucle de eventos X11. Al mover `ptcgraph` a un `.so`, hay
   que decidir explícitamente dónde vive el gestor de hilos (tarea `T5.9`).
8. **`SetGraphMode` es un no-op peligroso** en el port: hubo que blindarlo con
   `if BadVideoOrMouse then`. La ABI no debe resucitar ese camino.
9. **Dos RTL, dos heaps.** El ejecutable y el `.so` tienen cada uno su gestor
   de memoria de Free Pascal. Regla absoluta: **quien reserva, libera**. VPA
   reserva los buffers de `GetImage`/`PutImage` y el plugin solo los lee o
   escribe; el plugin reserva sus fuentes y las libera él.
10. **Escala y pantalla completa ya existen** y tienen semántica propia
    (`VPA_SCALE`: sin definir → 200; `1` → 100; `2..20` → N×100 por
    compatibilidad; `21..800` → porcentaje literal; `fullscreen` → el mayor
    porcentaje que cabe). Hay que conservarla **exactamente**, incluida la
    interpretación heredada.

---

## 3. Arquitectura objetivo

### 3.1 Esquema

```text
build/VPA                        (enlaza: libc, RTL de FPC, libdl)
│
├── GRAPH/vpagraph.pas           API pública (parece ptcgraph, no lo es)
├── GRAPH/vpagraph_loader.pas    única unidad que usa Dynlibs
├── GRAPH/vpagraph_detect.pas    auto | x11 | wayland
├── GRAPH/vpagraph_errors.pas    traducción de códigos de error
└── GRAPH/vpagraph_abi.inc       contrato compartido con los plugins
        │
        │  dlopen() de UNO solo, en tiempo de ejecución
        ▼
┌───────────────────────────────┬───────────────────────────────┐
│ libvpagraph-x11.so            │ libvpagraph-wayland.so        │
│  adaptador ABI                │  adaptador ABI                │
│  ptcgraph + ptccrt + ptcmouse │  motor de dibujo (fase 7-8)   │
│  ptc (consola X11) + xfocus   │  SDL3                         │
│  → libX11                     │  → libwayland-client          │
└───────────────────────────────┴───────────────────────────────┘
```

### 3.2 Por qué plugins y no compilación condicional

Si los dos backends se enlazaran dentro del binario, el cargador dinámico
exigiría las bibliotecas de ambos aunque solo se usara uno: en una máquina sin
SDL3 (Astra Linux, Kubuntu LTS antiguo, Raspberry Pi OS) `VPA` **no arrancaría
en absoluto**, ni siquiera en X11. Con plugins, la ausencia de SDL3 solo
significa que ese `.so` no carga y `auto` se queda en X11. Esto es lo que hace
que la arquitectura merezca la pena, más allá de la limpieza.

### 3.3 Estructura de directorios — **adaptada al repositorio real**

> **Cambio respecto al documento de partida.** La propuesta original usaba
> `src/`, `backends/`, `include/`. Trasladar `VPA/`, `UNIT/`, `VENDOR/`,
> `VHLP/` y `CC/` a `src/` produciría un diff gigantesco, rompería las rutas de
> `vpa.cfg`, las reglas de `.gitattributes`, el `Makefile`, los tres documentos
> de compilación y el guion de empaquetado, y todo eso **antes** de escribir una
> sola línea de Wayland. No compensa. Se mantiene el árbol actual y se añaden
> dos directorios nuevos siguiendo la convención existente (directorios de
> fuentes en mayúsculas):

```text
vpa-linux/
├── GRAPH/                        ← NUEVO: núcleo, se enlaza en el ejecutable
│   ├── vpagraph.pas
│   ├── vpagraph_loader.pas
│   ├── vpagraph_detect.pas
│   ├── vpagraph_errors.pas
│   └── vpagraph_abi.inc
├── BACKENDS/                     ← NUEVO: cada subdirectorio, un .so
│   ├── X11/
│   │   ├── vpagraph_x11.lpr
│   │   └── vpagraph_x11_impl.pas
│   └── WAYLAND/
│       ├── vpagraph_wayland.lpr
│       └── vpagraph_sdl3_*.pas
├── VENDOR/                       ← pasa a usarse SOLO desde BACKENDS/X11
├── VPA/  UNIT/  VHLP/  CC/       ← sin cambios de ubicación
├── TESTS/                        ← NUEVO: arneses de prueba de la ABI
├── Makefile                      ← objetivos nuevos: plugins, x11-plugin, wayland-plugin
├── vpa.cfg                       ← añadir -FuGRAPH -FiGRAPH
├── plugins.cfg                   ← NUEVO: configuración de compilación de los .so
└── WAYLAND.md                    ← este documento
```

Nombres de unidad en minúsculas y con guiones bajos, siguiendo el precedente de
`UNIT/xfocus.pas` (las mayúsculas 8.3 son herencia DOS del código original y no
hay motivo para imitarlas en código nuevo).

### 3.4 Reglas de la ABI

Innegociables, y la razón de cada una:

| Regla | Motivo |
|-------|--------|
| Convención `cdecl` en **todo** | Estable entre versiones de FPC y frente a un futuro backend en C |
| Solo tipos de tamaño fijo (`Int32`, `UInt32`…) | `Integer` cambia de tamaño según modo y arquitectura; tenemos x86_64 y aarch64 |
| Nada de `String`, `AnsiString`, `UnicodeString`, arrays dinámicos | Están gestionados por el RTL, y hay dos RTL |
| Nada de clases ni objetos Pascal | El diseño de VMT no es un contrato público |
| Ninguna excepción cruza la frontera | Desenrollar la pila entre dos RTL es comportamiento indefinido |
| Toda estructura empieza por `StructSize: UInt32` | Permite ampliar sin romper plugins antiguos |
| La interfaz lleva `ABIVersion: UInt32` | Rechazo limpio en vez de fallo aleatorio |
| Los errores se devuelven como entero; el texto se recoge en un buffer del llamante | Sin dudas sobre quién libera la memoria |
| Ningún puntero a memoria del RTL cruza la frontera salvo buffers crudos del llamante | Ver restricción 2.3.9 |

---

## 4. Decisión pendiente: el motor de dibujo del plugin Wayland

Esta es la única decisión grande que **no** se toma ahora. Se documenta para
tomarla con datos en la Fase 7.

> **Tomada el 2026-09-19: vía B** (D-06, `docs/adr-001-motor-wayland.md`). Lo
> que sigue se conserva como estaba, porque es el razonamiento previo a medir.

### 4.1 Vía A — reimplementar BGI sobre SDL3

Es la vía del documento de partida: el plugin Wayland mantiene su propio
framebuffer indexado de 8 bits y reimplementa sobre él las primitivas de Graph
(líneas con estilo, rectángulos, círculos, rellenos, viewport, modos de
escritura, imágenes, texto BGI), presentando el resultado como textura SDL de
32 bits.

- **A favor:** independencia total de PTCPas; control absoluto; camino natural
  hacia un `VPAGraphCore` común que a la larga permitiría jubilar `ptcgraph`.
- **En contra:** hay que reproducir, con fidelidad de píxel, lo que hoy hacen
  `VENDOR/graph.inc` (2291 líneas), `gtext.inc` (885), `fills.inc` (612),
  `palette.inc` (382), `clip.inc` (141) y `fontdata.inc` (2333). Y no basta con
  que «quede bien»: tiene que coincidir con el trazado de Bresenham exacto, el
  recorte exacto, la semántica exacta de XOR y el rasterizado exacto de las
  fuentes `.CHR`, porque si no el mapa estelar y los menús bailan respecto a
  X11. Las etapas 8 a 12 del plan original son, en realidad, este trabajo.

### 4.2 Vía B — consola PTC sobre SDL3 *(recomendada)*

PTCPas ya separa **qué se dibuja** de **dónde se presenta**. El dibujo vive en
el código genérico de `graph.inc`; lo específico de plataforma es la *consola*
(`IPTCConsole`), creada por `TPTCConsoleFactory.CreateNew` en
`VENDOR/ptc/core/consolei.inc`, con la implementación de X11 aislada en
`VENDOR/ptc/x11/`.

La vía B consiste en escribir una consola nueva, `VENDOR/ptc/sdl/`, que
implemente esa misma interfaz sobre SDL3: abrir ventana, `Lock`/`Unlock` de la
superficie de 8 bits, `Update`, paleta y cola de eventos. **Todo el dibujo se
reutiliza sin tocarlo.**

- **A favor:**
  - Equivalencia visual **por construcción**, no por comparación: las dos
    rutas ejecutan literalmente el mismo código de trazado. Las fases 8 a 12
    del plan original desaparecen casi por completo.
  - `ptccrt` y `ptcmouse` **también funcionan sin cambios**, porque tiran de la
    misma cola de eventos de la consola. La fase de teclado y ratón se reduce a
    mapear teclas.
  - `.CHR`, XOR, viewport, `ImageSize`, paletas: gratis y correctos.
  - Mucho menos código nuevo: se estima una consola de 600–900 líneas frente a
    varios miles de la vía A.
- **En contra:**
  - Hay que meterse dentro de PTCPas (código ajeno, LGPL con excepción de
    enlazado) y **vendorizar más partes de las que ya tenemos**: hoy
    `VENDOR/ptc/` solo trae `core/` y `x11/`, mientras que `ptcwrapper` y
    `Hermes` vienen del sistema (`fp-units-gfx`). Si la consola SDL obliga a
    tocar `ptcwrapper`, hay que vendorizarlo también.
  - La consola SDL no existe río arriba: PTCPas trae X11, Windows, DOS y Cocoa.
    Es código nuevo, aunque encaje en un hueco previsto.
  - Nos deja atados a PTCPas, que está poco mantenido.

### 4.3 Recomendación

**Vía B**, por una razón concreta: el riesgo del proyecto no está en abrir una
ventana en Wayland (eso es un fin de semana con SDL3), está en que *todo lo
demás siga dibujándose exactamente igual*. La vía A convierte ese riesgo en
varios miles de líneas de código nuevo que hay que validar píxel a píxel; la
vía B lo elimina de raíz reutilizando el trazado. La vía A sigue disponible
como plan de contingencia y como evolución futura (el `VPAGraphCore` común de
la sección 17 del documento de partida sigue teniendo sentido, pero *después*,
no ahora).

**Lo importante:** las fases 0 a 6 son **idénticas en ambas vías**. La decisión
no bloquea nada; se toma en la Fase 7, con un prototipo medido delante.

---

## 5. Fases

### Fase 0 — Preparación y red de seguridad ⚡

Antes de tocar una línea de código gráfico hay que poder demostrar que no se ha
roto nada. Las imágenes de referencia tienen que capturarse **con el binario
actual**, porque después ya no habrá «actual» con el que comparar.

- [x] **T0.1** — Crear la rama de trabajo `feature/wayland` a partir de `main`.
      La migración toca 25 unidades y va a durar semanas; `main` debe seguir
      siendo compilable y liberable en cualquier momento. Se integra a `main`
      por fusión al cerrar cada bloque (fases 0-6 primero, fases 7-12 después).
      — `ca514fa`
- [x] **T0.2** — Añadir este documento (`WAYLAND.md`) al repositorio. — `ca514fa`
- [x] **T0.3** — Registrar la línea base de dependencias del binario actual y
      guardarla en `docs/baseline-3.67.6.txt`:
      `readelf -d build/VPA | grep NEEDED` y `ldd build/VPA`. — `babf280`
      Resultado: el binario arrastra **siete** bibliotecas del servidor gráfico
      (`libX11`, `libXrandr`, `libXxf86vm`, `libXext`, `libXi`, `libXfixes` y,
      por dependencia, `libxcb`). Las siete tienen que haber desaparecido al
      cerrar la Fase 6 (`T6.12`).
- [x] **T0.4** — Implementar el **volcado de framebuffer** en el camino actual
      de `ptcgraph`: si `VPA_GRAPH_DUMP` está definida, volcar la superficie de
      640×480 más su paleta a un `.ppm` numerado. Es la herramienta que sostiene
      toda la validación posterior, y tiene que existir **antes** de que haya un
      segundo backend. — `e409022`

  Cómo quedó, porque son decisiones que habrá que respetar más adelante:

  - **Dónde.** En `VENDOR/ptcgraph.pp`, como código añadido
    (`VPADumpEnabled` / `VPADumpFrame`), no como modificación de ninguna rutina
    original; el aviso de modificación de la cabecera que exige la LGPL se ha
    ampliado con un cuarto punto. Se eligió ptcgraph y no `VPA/SCREEN.PAS`
    porque ahí están `ptc_surface_lock` y `ptc_palette_lock`, es decir el
    framebuffer tal y como se presenta, en vez de lo que `GetImage`
    reconstruye.
  - **Activación.** Variable de entorno `VPA_GRAPH_DUMP=<prefijo>`. Sin ella la
    funcionalidad no existe y no cuesta nada.
  - **Disparo.** `Ctrl-F12`, interceptado en `RawReadKey` de
    `UNIT/KEYBOARD.PAS`, que es el único punto por el que pasan todas las
    teclas de VPA. Verificado empíricamente: `ptccrt` traduce `Ctrl-F12` a
    `#0#138`, que VPA ve como **`$8A00`**, y ese código **no lo usa ninguna
    pantalla**. La tecla **no se consume**: sigue su camino y cae en el `else`
    de los `case`, igual que cualquier tecla desconocida. Consumirla obligaría
    a devolver otra cosa o a esperar a la siguiente, y eso sí cambiaría el
    comportamiento, porque `PreviewKey` se llama después de `KeyPressed` y no
    puede bloquear.
  - **Formato.** `<prefijo>NNNN.ppm` (PPM binario P6, sin comprimir, sin marca
    de tiempo en la cabecera: dos ejecuciones de la misma escena dan ficheros
    idénticos byte a byte) más `<prefijo>NNNN.pal` con las 256 entradas RGB en
    crudo, que permite distinguir una diferencia de dibujo de una diferencia de
    paleta.
  - **Cerrojos.** La paleta se copia y se suelta de inmediato; el de la
    superficie se mantiene durante la escritura del fichero. La alternativa
    —copiar los 300 KB del framebuffer a un buffer intermedio— obligaría a
    reservar ese bloque en el montón de VPA, que está ajustado y tiene
    historial de corrupciones; retener el cerrojo unos milisegundos en una
    captura manual es el riesgo menor.
  - **Verificado:** compilación limpia sin avisos nuevos (24 avisos y 221
    notas, exactamente los de la línea base), valores de paleta VGA exactos,
    dos ejecuciones de la misma escena con el mismo MD5, y el disparo por
    teclado probado inyectando `Ctrl-F12` en la ventana.
- [x] **T0.5** — Definir el **catálogo de escenas de referencia**: una lista
      corta y reproducible de pantallas de VPA que ejerciten lo que importa
      (mapa estelar con etiquetas, ventana de mensajes, menú Ctrl-O, simulador
      de combate, pantalla de puntuaciones, diálogo de construcción, salvapantallas).
      Documentar para cada una la secuencia exacta de teclas que la produce
      desde una partida de `EXAMPLES/`. — `c0cd087`

  Cómo quedó: `docs/reference-scenes.md` (20 escenas, `E01`–`E20`) y su forma
  ejecutable, `TESTS/capture.sh`, que arranca un VPA por escena sobre una copia
  limpia de la partida, inyecta las teclas con `xdotool` bajo `Xvfb` y dispara
  `Ctrl-F12`. Decisiones que condicionan todo lo posterior:

  - **Un proceso por escena, sobre copia limpia.** `VPAx.DB` guarda posición
    del mapa, zoom, capas visibles y reloj; `Ctrl-O` reescribe `VPA.INI` al
    salir. Encadenar escenas en un proceso contaminaría la siguiente.
  - **Puntero aparcado en (600,300) con `VPA_SCALE=1`.** La primera línea del
    panel derecho muestra las coordenadas de mapa bajo el puntero (o
    `2047M free` si está fuera del mapa): sin fijarlo, dos capturas iguales
    difieren ahí. Con escala 1 la ventana es la superficie y `xdotool` trabaja
    en coordenadas de superficie.
  - **El cursor del ratón no contamina:** lo dibuja el servidor X vía
    `ptcmouse`, no VPA. No aparece en el volcado.
  - **Salvapantallas descartado** de la comparación píxel a píxel:
    `VPA/SCRSAVER.PAS` usa `Random`. Se comprueba de otra forma (T6.14, Fase 9).
  - Se añaden desde ya las escenas frágiles que pedía T11.4 (XOR de la goma
    elástica, `GetImage`/`PutImage` del menú Ctrl-O y del visor de combate,
    viewport del panel derecho, paleta de estadísticas), para que las doradas
    de T0.6 ya las cubran y no haya que regenerarlas en la Fase 11.
  - Las secuencias salen de las pantallas de ayuda y del código; se validan
    una a una al capturar (T0.6), y el documento lleva una tabla para
    anotarlo.
- [x] **T0.5b** — Preparar la **partida de referencia** en `TESTS/fixture/`,
      **fuera del control de versiones**. La hoja de ruta daba por hecho que
      `EXAMPLES/` traía una partida, y no la trae: solo `VPA.INI` y un guion de
      lanzamiento. Requisitos en `docs/reference-scenes.md`, sección 2.3.
      Partida usada: The Robots, turno 90, raza 9, fijada en
      `TESTS/capture.sh` (`RACE=9`). — `c0dcf96`
      Decisión: `TESTS/fixture/` y `TESTS/golden/` van a `.gitignore`. Los
      datos del juego son de Tim Wisseman, los mensajes los han escrito otros
      jugadores de una partida real, `FIZZ.BIN` lleva la clave de registro, y
      las doradas son decenas de MB de binarios. Nada de eso debe entrar en un
      repositorio público, y lo que entra en el historial ya no sale: la
      decisión había que tomarla antes del primer commit, no limpiarla
      después. Se reincluyen `TESTS/golden/README.md` y `SHA256SUMS`, que
      dejan constancia de qué se capturó y con qué hashes.
      Coste aceptado: las doradas no son verificables por terceros. Son la red
      de regresión de quien hace la migración, no un artefacto publicable.
      Contrapartida práctica: la copia local es la única que hay, y un
      `git clean -xfd` se la lleva; conviene guardarla fuera del árbol.
  Endurecimiento de `TESTS/capture.sh` antes de T0.6, tras el primer intento
  fallido de captura, en el que todas las escenas fallaron con «no aparece la
  ventana» y ese no era el motivo:

  - **Directorio de ejecución propio.** VPA abre `VPA.HLP`, `RESOURCE.PLN` y
    `DISTTABL.DAT` por el nombre pelado, relativos al directorio actual y no a
    `addir` (`OpenFile`/`OpenData` en `VPA/VPADATA.PAS`), y aborta si faltan,
    antes de abrir la ventana. El guion monta ahora un directorio propio en el
    temporal con enlaces a esos ficheros y lanza VPA desde ahí, así que da
    igual desde dónde se ejecute. Los obligatorios se comprueban **antes** de
    arrancar Xvfb, con un mensaje que dice qué falta y de dónde sale.
  - **Salvapantallas apagado de verdad.** `VPA/VPA.INI` trae
    `ScreenSaverTime = 1`; el guion pone `0` en la copia que deja en el
    directorio de ejecución, y también en el `VPA.INI` de la partida si lo
    hubiera, porque ese se lee después y pisa (`ReadConfig1` en
    `VPA/CONFIG.PAS`). De paso, la configuración de las doradas queda fijada
    por el repositorio y no por el `~/PLANETS` de quien capture.
  - **Xvfb: espera activa, no `sleep`.** Con la espera fija de 2 s la primera
    escena podía arrancar antes de que el servidor aceptase conexiones y morir
    con «no display», fallando solo ella. Ahora se sondea con
    `xdotool getdisplaygeometry`.
  - **Ventana buscada por título exacto.** `WindowTitle := ParamStr(0)`
    (`VENDOR/ptcgraph.pp`), así que la ventana se llama como la ruta con la que
    se lanzó el binario; antes se cogía «cualquier ventana visible». Y si el
    proceso muere antes de abrirla, se distingue de «tarda» y se enseña la cola
    del log.
  - **Fin del volcado por el `.pal`.** `VPADumpFrame` escribe el `.ppm` y luego
    el `.pal`; esperar a que el `.pal` tenga sus 768 bytes garantiza que el
    `.ppm` está entero. Antes se esperaba a que el `.ppm` fuese no vacío.
  - **`VPA_KEYMODE`.** Por defecto `xtest`, con foco explícito
    (`xdotool windowfocus`), que es lo que hace falta sin gestor de ventanas;
    `sendevent` como alternativa. `ptc` no filtra `send_event`, así que valen
    las dos.

  **Diagnóstico futuro:** `stderr` se pierde en cuanto `OpenGraph` toma la
  pantalla, así que cualquier `Writeln(StdErr, ...)` posterior a la apertura de
  la ventana es invisible. Lo que haya que instrumentar a partir de ese punto
  tiene que escribirse a fichero.

  Y la causa real del fallo de las 19 escenas, que no era ninguna de las
  anteriores: **el puntero aparcado en (600,300)**. En `VPA/VPA2.PAS`, el bucle
  interno del `main` (`while mEvent<>0`) se rearma solo mientras el puntero
  este fuera de `8..471 x 8..477`, porque ahi VPA hace auto-scroll del mapa; y
  mientras hace auto-scroll **no vuelve a leer el teclado**. En una ventana de
  640 px, x=600 esta en el panel derecho, pasado el umbral. E17 era la unica
  escena que terminaba con el puntero dentro del mapa (300,200), y por eso era
  la unica que capturaba. El catalogo justificaba (600,300) diciendo que caia
  "dentro del mapa pero fuera del panel", que es al reves: de ahi salio el
  error. El aparcamiento pasa a (240,240) y la justificacion queda corregida en
  `docs/reference-scenes.md`, seccion 1.
  Bisectado: (240,240) vuelca, (475,300) -cuatro pixeles pasado el umbral- no,
  (600,300) no.

  Otros dos hallazgos de la misma tanda:

  - **`Cannot open X display` intermitente**, ~1 arranque de cada 20, en
    `TX11Console.CreateDisplay`: `XOpenDisplay` falla al encadenar arranques y
    muertes de proceso contra el mismo Xvfb. No depende de la escena (cayo en
    E19 en una pasada y en E16 en la otra, en la misma direccion). El guion deja
    medio segundo entre escenas y reintenta una vez, avisando.
  - **El indicador parpadeante de `ArrowBlink`** impide que algunas escenas sean
    exactas pixel a pixel. Detalle y decision pendiente en
    `docs/reference-scenes.md`, seccion 1.3.

  Estado del arnes tras esto: **las 20 escenas capturan**, y dos pasadas
  completas dan **19 de 20 identicas pixel a pixel**, siendo la vigesima E06 con
  30 pixeles del parpadeo. Medido en el contenedor de desarrollo con FPC 3.2.2 y
  un `RESOURCE.PLN` ficticio, que basta porque `OpenGraph` solo comprueba que el
  fichero existe (`OpenFile(f,ResName,0,Yes); CloseData(f)`); las doradas de
  T0.6 hay que sacarlas en la maquina de desarrollo con el fichero real.

  **Posible bug de VPA, no del arnes, anotado aqui para no perderlo:** mientras
  el puntero esta en la franja de auto-scroll, VPA ignora el teclado por
  completo. En uso interactivo se disimula porque uno aparta el raton, pero el
  bucle se come los eventos de tecla mientras tanto.

- [x] **T0.6** — Capturar las escenas de T0.5 con el binario 3.67.6 y guardarlas
      como **imágenes doradas** en `TESTS/golden/` junto con sus hashes.
      Documentar la versión de FPC y la máquina usada.
      Procedimiento: `TESTS/capture.sh TESTS/golden` sobre la partida de
      T0.5b; ejecutarlo **dos veces** en directorios distintos y pasar
      `TESTS/compare.py` entre ambos antes de dar nada por dorado (cero
      diferencias, o la escena no es reproducible y hay que entender por qué);
      `sha256sum TESTS/golden/*.ppm TESTS/golden/*.pal > TESTS/golden/SHA256SUMS`;
      rellenar la tabla de validación de `docs/reference-scenes.md`, sección
      5, y `TESTS/golden/README.md` con partida, raza, turno, versión de FPC,
      distribución y máquina.

  Confirmado en la máquina de desarrollo (2026-09-13):
  `TESTS/capture.sh` seguido de `TESTS/compare.py TESTS/golden /tmp/cap3` da
  **20 de 20 idénticas, 0 fallos**, contra unas doradas generadas en otra
  máquina. Con esto la Fase 0 queda cerrada.

  Cómo quedó. Al validar las 20 capturas de la máquina de desarrollo una a
  una contra la tabla del catálogo, **siete no mostraban lo que decía la
  tabla**, y cuatro de ellas eran duplicados byte a byte de otra escena (E07,
  E18 y E19 de E01; E20 de E04): la tecla no hacía nada. Causas y arreglos,
  con el detalle en `docs/reference-scenes.md`, secciones 3.1 y 5:

  - `s` y `p` desde el mapa actúan sobre el objeto actual (*sell supplies*,
    planeta bajo el puntero), no abren fichas. E06 y E07 seleccionan ahora
    por posición (`@X,Y` + `Return`, token nuevo de `TESTS/capture.sh`) la
    nave 1 en el vacío y el planeta Anditius, y **capturan con el puntero
    sobre el objeto**: `MouseMove` (`VPA/VPA2.PAS`) suelta el bloqueo y borra
    el panel en cuanto el puntero se aleja más de `StickyMouseRange`. Es una
    regla nueva de la sección 1 del catálogo: el panel pertenece al puntero.
  - `F1` desde el mapa abre la ayuda contextual del objeto actual, no la
    general; leyenda y créditos son páginas de la ayuda general (`VHLP/VPA.HHH`,
    tabla `KEY`), así que E19 y E20 pasan por `F1 space`. E04 y E05 cambian de
    título, no de secuencia.
  - `Return` en (240,240) reseleccionaba Carillon: E18 pasa a ser la ficha del
    campo de minas 7 (`1`, objeto del mismo punto).
  - `Ctrl-F10` dejaba el gráfico vacío: E13 activa las diez series (una letra
    cada una), que son las diez entradas de `StatColor`.
  - E10 dependía del editor instalado (`VPA/INI.PAS` resuelve `$VISUAL`,
    `$EDITOR`, `nano`, `vi`): el guion fija `VISUAL=/usr/bin/nano`.
  - Con E06 corregida, **ninguna escena cae en un bucle de `ArrowBlink`**: dos
    pasadas dan 20 de 20 idénticas sin tolerancia alguna. La decisión pendiente
    sobre la caja queda implementada igualmente, por si una escena futura lo
    necesita: `TESTS/compare.py` lee `TESTS/excepciones.txt`, una caja admitida
    por escena; los píxeles distintos dentro se cuentan aparte y los de fuera
    siguen siendo fallo. Hoy el fichero no tiene entradas, a propósito.

  Doradas: generadas en el contenedor de desarrollo con el `RESOURCE.PLN` real
  (Ubuntu 24.04, FPC 3.2.2, mismo binario de la rama), dos pasadas idénticas,
  `SHA256SUMS` y `README.md` en `TESTS/golden/`.

  **Y las veinte se reproducen exactamente en la máquina de desarrollo**
  (Arch, FPC 3.2.2, `RESOURCE.PLN` real): 307 200 píxeles idénticos en las
  veinte, imágenes de casco incluidas. Eso es más de lo que pedía el criterio,
  que solo exigía dos pasadas iguales en la misma máquina, y tiene una
  consecuencia práctica para las fases siguientes: **una diferencia frente a
  las doradas es una diferencia del backend, no del entorno**, así que la
  comparación se puede correr donde sea. Lo que sí depende de la máquina está
  acotado y documentado en `TESTS/golden/README.md`: el `RESOURCE.PLN` (E14 y
  E16) y el editor instalado (E10, ya fijado por el guion).
- [x] **T0.7** — Escribir `TESTS/compare.py`: compara dos volcados `.ppm`,
      informa del número de píxeles distintos, su localización y genera una
      imagen de diferencias. Sin dependencias externas más allá de la
      biblioteca estándar (el repositorio ya usa Python en `preport.py`).
      — `62c960b`
      Compara ficheros sueltos o directorios enteros; informa de número y
      porcentaje de píxeles distintos, caja envolvente de los cambios, primer
      píxel discrepante, delta máximo por canal y, si los `.pal` difieren, qué
      entradas de paleta han cambiado. Con `--diff-dir` escribe un PNG por par
      con los píxeles distintos en magenta sobre la captura atenuada.
      `--tolerancia=N` admite hasta N píxeles, y el código de salida es 0 si
      todo cuadra y 1 si no, para poder encadenarlo en un guion.
- [x] **T0.8** — Verificar que la captura funciona en `xvfb-run` sin display
      real, para poder automatizarla. — `e409022`

**Criterio de aceptación de la Fase 0:**
`TESTS/capture.sh` ejecutado dos veces sobre `TESTS/fixture/` produce las 20
escenas de `docs/reference-scenes.md`, y `TESTS/compare.py` da 0 píxeles de
diferencia entre las dos ejecuciones, **salvo en las escenas que caen en un
bucle de `ArrowBlink`**, donde la diferencia admisible es la caja del indicador
y nada más (`docs/reference-scenes.md`, sección 1.3). El criterio original pedía
cero píxeles en todas; con el parpadeo eso es inalcanzable, y fingir que se
cumple seria peor que anotarlo.

**Estado: cumplido** (2026-09-13), y sin necesitar la excepción. Tras corregir
las secuencias en T0.6, dos pasadas completas dan **20 de 20 idénticas píxel a
píxel**, y la comparación de una pasada nueva contra las doradas hechas en otra
máquina también. El parpadeo que motivó la excepción estaba en la E06 antigua,
cuya secuencia no abría la ficha de nave sino el diálogo *sell supplies*; la
cláusula se queda escrita por si una escena futura cae en un bucle de
`ArrowBlink`, con `TESTS/excepciones.txt` como mecanismo, hoy vacío.

Resuelto en T0.6: la E06 que parpadeaba no era la ficha de nave, y con la
secuencia corregida ninguna escena cae en `ArrowBlink`; dos pasadas dan 20 de
20 idénticas. Para el caso futuro, `TESTS/compare.py` admite una caja por
escena en `TESTS/excepciones.txt` (hoy vacío).

---

### Fase 1 — Inventario de la frontera gráfica 🔒

Objetivo: que no quede ni una llamada al mundo exterior sin catalogar. La tabla
de la sección 2.2 es el punto de partida, no el resultado.

- [x] **T1.1** — `docs/vpagraph-api-inventory.md`, tabla 1: **API Graph**. Para
      cada símbolo: nombre, firma exacta tal y como la declara
      `VENDOR/graphh.inc`, número real de llamadas (excluyendo comentarios),
      ficheros afectados, prioridad (`v1` / `v2` / `no usada`), complejidad y
      equivalencia prevista en el backend nuevo. — `2e6b853`
      Las cuentas las produce `TESTS/inventory.py` (`c22e284`), que además
      separa lo que el ejecutable enlaza de lo que no (ver D-07). Son 32
      entradas para la v1; `Line` tiene 270 llamadas reales, no 397.
- [x] **T1.2** — Tabla 2: **constantes y tipos** de `ptcgraph` que usa VPA
      (`D8bit`, `m640x480`, `XORPut`, `NormalPut`, `CopyPut`, `HorizDir`,
      `SmallFont`, `DefaultFont`, `SolidLn`, `SolidFill`, `ColorType`,
      `PaletteType`, `ViewPortType`, `grOk`…). Cada una tiene que ser
      reexportada por `VPAGraph` o el `uses` no se podrá sustituir de una pieza.
      — `2e6b853`
      41 símbolos con su valor. `CopyPut` y `PaletteType` no se usan.
- [x] **T1.3** — Tabla 3: **teclado** (`ptccrt`). Documentar el camino completo
      desde la pulsación hasta `Keyboard.ReadKey`, incluyendo `PTCLastKbdFlags`
      y `PTCQuitNoSave`, y el arreglo de 3.67.5 para `Ctrl-+`/`Ctrl--` en
      distribuciones de teclado no estadounidenses (se resolvió comparando el
      **carácter Unicode**, no el scancode: es un requisito, no un detalle).
      — `2e6b853`
- [x] **T1.4** — Tabla 4: **ratón** (`ptcmouse`), incluyendo la emulación por
      software de `StickyMouseRange` en `UNIT/MOUSE.PAS` (`ptcmouse` no expone
      limitación de rango). — `2e6b853`
      Precisión: el rango lo emula `SetMouseRange`/`PollMouse` por recorte;
      `StickyMouseRange` es lógica de VPA en `SCREEN`/`VPA2` que solo pide al
      backend el *warp* del puntero.
- [x] **T1.5** — Tabla 5: **ventana y foco** (`xfocus`), con las 19 llamadas de
      la sección 2.1 y, para cada una, qué necesita realmente del servidor
      gráfico. Es la tabla que define la mitad menos obvia de la ABI.
      — `2e6b853`
      De once funciones, cuatro peticiones reales (ver D-08).
- [x] **T1.6** — Documentar el **contrato de formato de imagen**: diseño exacto
      del buffer de `GetImage`/`PutImage` en `D8bit` (cabecera de 12 bytes con
      tres `longint`, un `word` por píxel), con referencia a los sitios de
      `VPA/TCOMBAT.PAS` y `VPA/EXTFEAT.PAS` que lo construyen a mano.
      — `2e6b853`
- [x] **T1.7** — Documentar el **contrato de paleta**: cómo entra la paleta VGA
      de VPA (valores de 6 bits 0..63 en orden R,B,G en los ficheros originales,
      convertidos a 0..255 RGB para `ptcgraph`, ver `VPA/TCOMBAT.PAS:1438`).
      — `2e6b853`
- [x] **T1.8** — Lista de símbolos **declarados pero no usados** por VPA, con la
      decisión explícita de dejarlos fuera de la ABI v1. — `2e6b853`
- [x] **T1.9** — Revisión cruzada: `grep` sobre `VPA/`, `UNIT/`, `CC/`, `VHLP/`
      buscando cualquier identificador de `ptcgraph`, `ptccrt`, `ptcmouse`, `ptc`
      o `xlib` que no aparezca en el inventario. — `2e6b853`
      Nada nuevo: solo `UNIT/xfocus.pas` habla Xlib (49 llamadas, todas en la
      tabla 5); fuera de los símbolos quedan anotados `cthreads` y las
      variables de entorno `VPA_SCALE`, `VPA_GRAPH_DUMP`, `VPA_FULLSCREEN`.

**Criterio de aceptación:** el inventario cubre el 100 % de los símbolos que
cruzan la frontera; T1.9 no encuentra nada nuevo.

**Estado: cumplido** (2026-09-13). `TESTS/inventory.py` recorre los 396
símbolos exportados por las cuatro unidades de la frontera y todos los que
tienen uso están en las tablas; el `grep` de `ptc*`/`X*` no encuentra nada
fuera de `xfocus`. El documento cierra con la lista de lo que cambia respecto a
la sección 2 de aquí, que es la entrada de la Fase 2.

---

### Fase 2 — Definición de la ABI v1 🔒

- [x] **T2.1** — Crear `GRAPH/vpagraph_abi.inc` con la constante
      `VPAGRAPH_ABI_VERSION = 1` y los tipos de tamaño fijo
      (`TVPAGraphInt8/16/32`, `TVPAGraphUInt8/16/32/64` y sus punteros).
      — `d68fd91`
      Definidos sobre los tipos base de Pascal, no sobre `Int32`/`UInt32`, que
      no existen en los dos modos. Se añade `TVPAGraphBool` (un byte).
- [x] **T2.2** — Definir los **códigos de error**. Punto de partida del
      documento original, que es bueno: `0` correcto, `-1` parámetro inválido,
      `-2` ABI incompatible, `-3` tamaño de estructura inválido, `-10` error de
      inicialización, `-20` error de vídeo, `-30` error de memoria, `-100`
      excepción interna capturada. Añadir `-40` «función no soportada por este
      backend». — `d68fd91`
- [x] **T2.3** — Definir `TVPAGraphInitParams`: `StructSize`, ancho y alto
      lógicos, escala en porcentaje (sustituye a la variable global
      `ptcgraph.VPAForceScale`), indicador de pantalla completa, título de
      ventana como `PAnsiChar`. — `d68fd91`
- [x] **T2.4** — Definir `TVPAGraphInterface`: `StructSize`, `ABIVersion`,
      `BackendName`, `BackendVersion` y los punteros a función. **Orden fijo y
      solo se añade al final**, nunca en medio. — `d68fd91`
      44 funciones y ocho casillas `Reserved` para crecer sin mover nada.
- [x] **T2.5** — Bloque de funciones de **ciclo de vida**: `Init`, `Shutdown`,
      `GetLastError(Buffer, BufferSize)`, `Present`, `GraphResult`.
      — `d68fd91`
      Se añaden `Suspend`/`Resume`, que no estaban en el plan: son la pareja
      que sustituye a `RestoreCrtMode`+`SetGraphMode(GetGraphMode)` y a la
      terna de `xfocus` que siempre la sigue (D-08).
- [x] **T2.6** — Bloque de **dibujo** (el subconjunto real de la Fase 1, no la
      API Graph completa): `ClearDevice`, `ClearViewPort`, `SetViewPort`,
      `GetViewSettings`, `SetColor`, `GetColor`, `SetBkColor`, `SetLineStyle`,
      `SetFillStyle`, `SetWriteMode`, `PutPixel`, `GetPixel`, `Line`, `LineTo`,
      `LineRel`, `MoveTo`, `Rectangle`, `Bar`, `Circle`, `Ellipse`.
      — `d68fd91`
      Con dos descartes: `ClearViewPort` y `SetBkColor` no los usa VPA
      (tabla 9 del inventario) y, siendo la estructura ampliable solo por el
      final, añadirlos el día que hagan falta no cuesta nada (D-11).
      `Ellipse` entra con ángulos y dos radios: la única llamada es un arco.
- [x] **T2.7** — Bloque de **imágenes**: `ImageSize`, `GetImage`, `PutImage`,
      con el contrato de memoria de T1.6 documentado **dentro del `.inc`**, en
      comentario, no solo en el inventario. — `d68fd91`
      `GetImage`/`PutImage` reciben además el tamaño del búfer: es la única
      defensa posible contra un tamaño mal calculado al otro lado.
- [x] **T2.8** — Bloque de **paleta**: `SetRGBPalette`, `GetRGBPalette` y lo que
      T1.7 determine. Las tablas se pasan por puntero más número de entradas,
      nunca como array Pascal. — `d68fd91`
      T1.7 determinó que hacía falta un tercero, `SetRGBPaletteBlock`, para el
      combate, que reescribe quince entradas seguidas.
- [x] **T2.9** — Bloque de **texto**: `OutTextXY(X, Y, PAnsiChar)`,
      `SetTextStyle`, `SetTextJustify`, `TextWidth`, `TextHeight`,
      `InstallUserFont(PAnsiChar)`. Decisión a dejar escrita: la conversión
      shortstring → `PAnsiChar` ocurre **solo** en `GRAPH/vpagraph.pas`.
      — `d68fd91`
      `TextWidth` (solo la usa `CC/MSGWIN.PAS`, no enlazado) y `TextHeight`
      (nadie) se descartan por D-11, igual que arriba.
- [x] **T2.10** — Bloque de **ventana, foco y escala** (la aportación que no
      estaba en el plan original): `ResolveScale`, `ApplyWindowScale`,
      `GrabInputFocus`, `ReleaseInputFocus`, `RequestFullscreen`,
      `ReleaseFullscreen`, `WantFullscreen`, `PointerInsideWindow`,
      `MapMouseToSurface`, `MapSurfaceToWindow`, `BackendReady`.
      — `d68fd91`
      Reducido a tres funciones por D-08: `GetScreenSize`, `SetFullscreen` y
      `GetWindowSize`. `ResolveScale` y `WantFullscreen` son lógica de VPA y
      se quedan en el núcleo; `GrabInputFocus`, `ApplyWindowScale` y los dos
      `Map*` sobraban en cuanto la ventana la crea el plugin;
      `PointerInsideWindow` pasa a ser un parámetro de `GetMouseState`;
      `BackendReady` lo sustituye el código de retorno de `Init`.
- [x] **T2.11** — Bloque de **teclado y ratón**: `KeyPressed`, `ReadKey`,
      `GetKbdFlags`, `GetQuitNoSave`, `ShowMouse`, `HideMouse`,
      `GetMouseState`, `SetMousePos`, y `PollEvent(EventOut)` con la
      convención `0` sin evento / `1` evento / negativo error. — `d68fd91`
      `KeyPressed`, `ReadKey` y `GetQuitNoSave` **no entran en la ABI** (D-10):
      la traducción a scancodes de Turbo Pascal y el búfer de teclas viven en
      el núcleo, porque si cada backend tradujera por su cuenta, X11 y Wayland
      divergirían en teclas raras. `GetKbdFlags` se llama `GetModifiers`;
      `ShowMouse`/`HideMouse` se funden en `ShowMouse(Show)`.
- [x] **T2.12** — Definir `TVPAGraphEvent` (`StructSize`, `EventType`,
      `Timestamp`, `KeyCode`, `ScanCode`, `UnicodeChar`, `Modifiers`, `MouseX`,
      `MouseY`, `MouseButton`, `Width`, `Height`). **`UnicodeChar` es
      obligatorio**: sin él no se puede replicar el arreglo de `Ctrl-+`/`Ctrl--`
      de 3.67.5. — `d68fd91`
      Los códigos de tecla `VPAGK_*` reutilizan los valores de los `PTCKEY_*`
      de PTCPas en vez de inventar una numeración nueva.
- [x] **T2.13** — Definir el prototipo del punto de entrada único
      `VPAGraph_GetInterface(RequestedABIVersion, InterfaceSize, InterfaceOut)`.
      — `d68fd91`
      La estructura la reserva el núcleo y se la pasa al plugin, que no puede
      escribir más allá de `InterfaceSize`.
- [x] **T2.14** — Escribir `docs/abi-compatibility.md`: qué se puede cambiar sin
      subir la versión de ABI (nada que altere el diseño existente), qué obliga
      a subirla y cómo se comporta un plugin viejo ante un ejecutable nuevo y
      viceversa. — `2ff5750`
      Incluye la lista de funciones obligatorias y opcionales, que es lo que
      tiene que comprobar el cargador de la Fase 3.
- [x] **T2.15** — Escribir `TESTS/abi/stub_backend.lpr`: un plugin de juguete
      que no dibuja nada pero devuelve una interfaz válida. Es el banco de
      pruebas del cargador de la Fase 3. — `90ac096`
- [x] **T2.16** — Escribir también los plugins **defectuosos** de prueba: uno
      sin el símbolo de entrada, uno con `ABIVersion` = 99, uno con
      `StructSize` incorrecto y uno que devuelve punteros nulos en funciones
      obligatorias. — `90ac096`

**Criterio de aceptación:** `vpagraph_abi.inc` compila tanto desde una unidad en
`-Mtp` como desde una en `{$mode objfpc}`, y `stub_backend.so` se construye.

**Estado: cumplido** (2026-09-13), con FPC 3.2.2. `TESTS/abi/abi_tp.pas` y
`TESTS/abi/abi_objfpc.pas` compilan sin avisos, y las cinco bibliotecas de
`TESTS/abi/` se construyen y exportan (o no, en el caso de `bad_nosymbol`) el
símbolo esperado.

Se comprobó además algo que el criterio no pedía y que habría sido un fallo
silencioso: que los **dos modos producen la misma disposición en memoria**.
`TVPAGraphEvent` mide 72 bytes, `TVPAGraphInitParams` 32 y
`TVPAGraphInterface` 440 en `-Mtp` y en `objfpc`, con los mismos
desplazamientos. Si los modos empaquetaran distinto, los dos lados compilarían
igualmente y la ABI estaría rota de nacimiento. La comprobación queda escrita
como aserciones de compilación en los dos ficheros de prueba.

---

### Fase 3 — Cargador dinámico 🔒

- [x] **T3.1** — `GRAPH/vpagraph_loader.pas`. **Única unidad de todo el
      proyecto que puede usar `Dynlibs`.** Anotarlo en su cabecera.
      — `1bb0ee7`
      Única unidad que carga bibliotecas, sí, pero con `dl` en vez de
      `Dynlibs`, y la cabecera explica por qué: `Dynlibs.LoadLibrary` abre
      con `RTLD_LAZY`, y con enlace perezoso un plugin al que le falte **un**
      símbolo de su biblioteca gráfica (un `libSDL3` más viejo que el usado
      al compilar: Astra, Kubuntu LTS) cargaría bien y caería en mitad de la
      partida. Con `RTLD_NOW` el fallo se ve en `dlopen`, con su mensaje, y
      `auto` cae a X11 como debe (D-12).
- [x] **T3.2** — Resolución de la ruta del plugin, en este orden:
      1. `$VPA_GRAPH_PLUGIN_DIR` si está definida;
      2. `<directorio del ejecutable>/plugins/` (para ejecutar sin instalar);
      3. el directorio de instalación (`/usr/lib/vpa-linux/`, ajustable en
         tiempo de compilación).
      Siempre rutas absolutas; **nunca el directorio de trabajo actual**.
      — `1bb0ee7`
      El directorio del ejecutable sale de `/proc/self/exe`, no de
      `ParamStr(0)`. Una `$VPA_GRAPH_PLUGIN_DIR` relativa se ignora y queda
      dicho en el motivo acumulado. El directorio de instalación es una
      constante en `GRAPH/vpagraph_installdir.inc`, para que el empaquetador
      o el `Makefile` (Fase 12) lo cambien sin tocar la unidad. El fichero
      del backend `x` se llama `libvpagraph-x.so`.
- [x] **T3.3** — Validaciones de seguridad antes de `LoadLibrary`: el fichero
      existe, es un fichero regular (no enlace a dispositivo ni directorio), y
      es legible. — `1bb0ee7`
- [x] **T3.4** — Carga, resolución de `VPAGraph_GetInterface` y llamada con la
      versión y el tamaño de estructura que espera el ejecutable. — `1bb0ee7`
- [x] **T3.5** — Validación de la tabla devuelta: `StructSize` coherente,
      `ABIVersion` compatible, `BackendName`/`BackendVersion` no nulos, y
      **todos** los punteros obligatorios asignados. Un plugin a medio rellenar
      se rechaza entero: no se acepta «funciona a medias». — `1bb0ee7`
      El mensaje de rechazo nombra las funciones que faltan, no solo cuántas.
      Al escribir esta comprobación se vio que `bad_nullprocs.lpr` no fijaba
      `BackendVersion` y caía una comprobación antes de la que quería probar;
      corregido en `a0c275e`.
- [x] **T3.6** — Descarga ordenada: anular la tabla de funciones *antes* de
      `UnloadLibrary`, para que un fallo posterior dé un puntero nulo detectable
      y no un salto a memoria liberada. — `1bb0ee7`
- [x] **T3.7** — Registro de diagnóstico: qué plugin se intentó, desde qué ruta,
      con qué resultado. Silencioso por defecto, detallado con
      `VPA_GRAPH_DEBUG=1`. — `1bb0ee7`
      Además, `VPAGraph_LoadBackend` acumula **un motivo por candidato** en
      el detalle que devuelve, que es la lista que T4.2 tiene que enseñar.
- [x] **T3.8** — `GRAPH/vpagraph_errors.pas`: traducción de códigos numéricos a
      texto en español y en inglés, y recogida del mensaje del plugin vía
      `GetLastError` con buffer del llamante. — `11a55d1`
      Traduce las dos familias: los `VPAG_ERR_*` de la ABI y los
      `VPAGL_ERR_*` del cargador, que viven en el cargador y no en el `.inc`
      porque nunca cruzan la frontera.
- [x] **T3.9** — `TESTS/abi/loader_test.lpr`: carga el stub, lo descarga, lo
      vuelve a cargar 100 veces y comprueba que no hay fugas (`-gh`).
      — `f43995c`
      Compara además heap del RTL y número de entradas de `/proc/self/fd`
      antes y después de los cien ciclos. `loader_tp.pas` hace para las dos
      unidades nuevas lo que `abi_tp.pas` para el `.inc`: compilar desde
      `-Mtp`.
- [x] **T3.10** — Probar el cargador contra los cuatro plugins defectuosos de
      T2.16: los cuatro deben ser rechazados con un mensaje distinto y útil.
      — `f43995c`
      Y contra un quinto, `bad_unresolved.lpr` (`5a30c4d`), que depende de un
      símbolo inexistente: es la prueba de que `RTLD_NOW` hace lo que T3.1
      promete. Los objetivos `make abi-plugins` y `make loader-test`
      (`7a2e6b3`) construyen y ejecutan todo esto.

**Criterio de aceptación:** el ejecutable de prueba carga el stub, rechaza los
cuatro plugins malos con mensajes diferenciados, y 100 ciclos de carga/descarga
no dejan memoria ni descriptores colgando.

**Estado: cumplido** (2026-09-15), con FPC 3.2.2. `make loader-test`: 70
comprobaciones correctas, cinco plugins defectuosos rechazados con cinco
códigos y cinco mensajes distintos, y `heaptrc` cierra con
`0 unfreed memory blocks` tras los cien ciclos (5 descriptores antes y
después; 1536 bytes de heap antes y después). `make build` sigue limpio: el
camino X11 no se ha tocado.

Detalle de `heaptrc` que conviene saber: en 3.2.2 no escribe nada en `stderr`
cuando no hay nada que decir, así que el objetivo `loader-test` manda su
resumen a `build/abi/loader_test.heaptrc` con `HEAPTRC=log=...` y lo comprueba
ahí.

---

### Fase 4 — Detección y selección de backend 🔒

- [x] **T4.1** — `GRAPH/vpagraph_detect.pas`, con soporte de
      `VPA_GRAPH_BACKEND` con valores `auto` (por defecto), `x11` y `wayland`.
      — `18bc868`
      El valor se normaliza (minúsculas, sin espacios; vacío = `auto`) y
      cualquier otro se rechaza con `VPAGD_ERR_BAD_REQUEST` y la lista de
      valores válidos. Solo por variable de entorno: no hay opción `/X` ni
      `--graph-backend` en la línea de comandos (D-14).
- [x] **T4.2** — Algoritmo de detección automática:
      1. si `WAYLAND_DISPLAY` está definida → intentar Wayland;
      2. si no, o si falla, y `DISPLAY` está definida → intentar X11;
      3. si `XDG_SESSION_TYPE` está definida, usarla como desempate;
      4. si fallan todos, error con **la lista acumulada de motivos**, no un
         genérico «no se pudo iniciar el modo gráfico».
      — `18bc868`
      El resultado es un **plan** (`TVPAGraphPlan`): lista ordenada de
      backends con el motivo de cada puesto. Con las dos variables definidas
      el orden es `[wayland, x11]` salvo que `XDG_SESSION_TYPE=x11`, que lo
      invierte; con una sola, solo ese backend (sin `DISPLAY` no hay servidor
      X al que caer, y al revés); sin ninguna, `[wayland]` si
      `XDG_SESSION_TYPE=wayland` (libwayland usa el socket por defecto) y si
      no `VPAGD_ERR_NO_SESSION`. Los motivos se acumulan uno por candidato
      del cargador y por backend del plan.
- [x] **T4.3** — **Regla de no-degradación silenciosa.** Con
      `VPA_GRAPH_BACKEND=wayland`, si el plugin Wayland falla, `VPA` termina con
      error. No cae a X11. Igual en sentido contrario. El respaldo solo existe
      en modo `auto`. — `18bc868`
      Garantizada por construcción: un backend forzado da un plan de una sola
      entrada, sin mirar el entorno, y no hay a dónde caer. El núcleo de la
      Fase 6 debe recorrer el plan él mismo con `VPAGraph_LoadPlanEntry`
      (carga → `Init` → siguiente solo si `not Forced`), porque un `Init`
      fallido también cuenta como fallo para el respaldo; `VPAGraph_SelectBackend`
      (solo carga) es para `--graph-info`.
- [x] **T4.4** — Implementar `--graph-info`: imprime backend solicitado, backend
      elegido, ruta del plugin, versión de ABI, versión del backend y
      controlador de vídeo subyacente, y sale sin abrir ventana. Herramienta de
      diagnóstico número uno para los informes de Alexander. — `ad0ba5c`
      `GRAPH/vpagraph_info.pas`. Se intercepta en `VPA.PAS`, **antes de
      instalar `Terminate`** y por tanto antes de `Parameters`: `Terminate`
      pone `ExitCode` a 0 en cualquier `Halt` (y escribía «Error 1 has
      occurred»), y `Parameters` rechaza con «Race = 1..11» cualquier
      `ParamStr(1)` de más de dos caracteres. Sale con 0 si eligió backend y
      1 si no. El «controlador de vídeo subyacente» no tiene campo en la ABI
      v1 y no se puede preguntar sin `Init`: cada plugin lo declara en
      `BackendVersion` y el informe imprime además el entorno de sesión
      completo (D-15). Adelanta T6.4 (`-FuGRAPH`, `-FiGRAPH` en `vpa.cfg`).
      Hasta la Fase 5 informa, correctamente, de que `libvpagraph-x11.so` no
      existe en ningún candidato. Dos limitaciones heredadas que desaparecen
      en la Fase 6 al sacar `ptcgraph`/`ptccrt` del ejecutable: como `/?`,
      necesita una sesión gráfica para arrancar (`ptcgraph` abre la conexión
      en su `initialization`), y la salida pasa por la consola de `ptccrt`,
      que la parte a 80 columnas.
- [x] **T4.5** — Ampliar `--help` para documentar las variables de entorno
      nuevas junto a las existentes (`VPA_SCALE`, `VPA_FULLSCREEN`, `VPA_VIDEO`).
      — `71ba70f`, `d4e4839`
      `--help`/`-h` en `Parameters`, antes de la comprobación de longitud:
      todo lo que dice `/?` más `VPA_SCALE`, `VPA_GRAPH_BACKEND`,
      `VPA_GRAPH_PLUGIN_DIR`, `VPA_GRAPH_DEBUG` y `VPA_GRAPH_DUMP`. `/?` se
      conserva intacto (es lo que el usuario conoce) y solo remite a
      `--help`. **`VPA_FULLSCREEN` y `VPA_VIDEO` quedan fuera**: hoy no las
      lee nadie (`xfocus.FullscreenRequested` no tiene llamadores) y
      documentarlas sería prometer algo que no ocurre hasta T10.4 (D-16).
      *2026-09-20: retiradas del todo (D-27).*
      Documentado en `HOWTO.es.md` y `HOWTO.en.md` (§2).
- [x] **T4.6** — Pruebas: los seis casos de la matriz
      (`auto`/`x11`/`wayland`) × (sesión X11 / sesión Wayland). — `af7bad7`
      `TESTS/abi/detect_test.lpr` y `make detect-test`: sesiones simuladas
      con `WAYLAND_DISPLAY`/`DISPLAY`/`XDG_SESSION_TYPE` y dos copias del
      stub renombradas como `libvpagraph-x11.so` y `libvpagraph-wayland.so`.
      Además de la matriz: T4.3 en los dos sentidos, el respaldo de `auto`,
      el desempate, los casos sin sesión y los valores inválidos. No necesita
      pantalla ni backend real. Wayland de verdad se prueba en la VM de
      Slackware/KDE a partir de la Fase 8.

**Criterio de aceptación:** la selección forzada nunca cambia de backend en
silencio; `--graph-info` da una salida correcta en ambos entornos.

**Estado: cumplido** (2026-09-15), con FPC 3.2.2. `make detect-test`: 67
comprobaciones correctas, incluidas las seis de la matriz y las dos de
no-degradación (backend forzado sin plugin: error, y el otro backend ni se
menciona). `make loader-test` sigue en 70/70 sin fugas; `make build` limpio
(los mismos 19 avisos de siempre) y `readelf -d build/VPA` no gana ninguna
biblioteca (`dlopen` vive en `libc` desde glibc 2.34). Los textos que ven los
usuarios (detalles del cargador, motivos, `--help`, `--graph-info`) están en
inglés (D-13).

---

### Fase 5 — Plugin X11: gráficos, ventana, teclado y ratón 🔒

La fase más delicada de todas, porque no aporta ninguna funcionalidad nueva y
puede romper lo que ya funciona. La meta es **comportamiento idéntico, bit a
bit**, con `ptcgraph` accedido a través del `.so`.

> **Planificación (2026-09-16).** Cómo se concilia esta fase con la regla 5:
> **la Fase 5 no toca el ejecutable.** Ni `VPA/`, ni `UNIT/`, ni `vpa.cfg`.
> `build/VPA` sigue enlazando `ptcgraph` y `xfocus` estáticos, y el `.so` es un
> artefacto nuevo que solo ejercita el arnés de T5.11. Por construcción, X11 no
> puede empeorar. El código Xlib de `UNIT/xfocus.pas` **no se traslada, se
> reescribe** en el plugin en su forma ABI (solo lo que sobrevive según D-08);
> `xfocus.pas` sigue intacto en el ejecutable hasta que T6.8 lo borra. La
> convivencia dura una fase y no es un segundo camino dentro de VPA (regla 2),
> porque VPA no lo usa: es el destino, ya construido y probado, del cambio de la
> Fase 6. Con la misma lectura se han corregido T5.1 (los `.ppu` de `build/`
> no son PIC), T5.6, T5.7 y T5.8 (posterior a D-10) y se ha añadido T5.3b.

- [x] **T5.1** — Crear `plugins.cfg` para compilar los `.so`: `{$mode objfpc}`,
      código independiente de posición, salida a `build/plugins/`. **No**
      hereda `-Mtp` ni las comprobaciones desactivadas de `vpa.cfg`: durante
      el desarrollo el código propio de `BACKENDS/` se compila con las
      comprobaciones **activadas**.
      *Corrección (2026-09-16):* el plan original decía «rutas de unidades a
      `build/ptcunits/`», pero esos `.ppu` no son PIC y no pueden entrar en un
      `.so`. El plugin necesita su **propia compilación de `ptc` y `ptcgraph`
      con `-Cg`**, en `build/plugins/units/`, hecha por un objetivo de
      `Makefile` aparte con las mismas opciones que hoy (`-O2`, comprobaciones
      desactivadas) para que el resultado sea píxel-idéntico. `plugins.cfg`
      con comprobaciones activadas se aplica solo a `BACKENDS/`. — `19e1b78`
- [x] **T5.2** — Añadir al `Makefile` los objetivos `plugins`, `x11-plugin` y
      (más adelante) `wayland-plugin`, respetando `.NOTPARALLEL` y la
      dependencia con el objetivo `ptc` existente. — `19e1b78`
- [x] **T5.3** — `BACKENDS/X11/vpagraph_x11.lpr`: biblioteca que exporta
      únicamente `VPAGraph_GetInterface`. — `e3ebc70`
- [x] **T5.3b** — Vendorizar `ptcwrapper.pp` (de fpcsrc 3.2.2, misma LGPL y
      mismo aviso de modificación que `ptcgraph.pp`) y añadir un método
      `X11WindowID` a `TX11Console` de `VENDOR/ptc/` con su paso a través en
      el wrapper (decisión D-18). Hoy se enlaza el `ptcwrapper.ppu` **del
      sistema** contra nuestro `ptc` vendorizado; vendorizarlo también cierra
      esa dependencia implícita. — `a26ea33`
- [x] **T5.4** — `BACKENDS/X11/vpagraph_x11_impl.pas`: adaptadores `cdecl` que
      envuelven `ptcgraph`. Cada uno con su `try..except` propio, porque
      **ninguna excepción puede cruzar** (regla 3.4). Traducción de shortstring:
      el adaptador recibe `PAnsiChar` y llama a `ptcgraph` con `string`. — `e3ebc70`
      (bloques T2.5 a T2.9 y `DumpFrame`; ventana y entrada, en T5.7 y T5.8)
- [x] **T5.5** — Adaptar el ciclo de vida: `Init` traduce
      `TVPAGraphInitParams` a `VPAForceScale` + `InitGraph(D8bit, m640x480, '')`;
      `Shutdown` llama a `CloseGraph`. Conservar la protección de 3.67.5 contra
      `SetGraphMode` destruyendo la ventana. — `e3ebc70`
- [x] **T5.5b** — **`Init` sin servidor X debe fallar limpio.** Hoy `dlopen` del
      plugin funciona sin `DISPLAY` (T5.9, 3.2), pero `Init` aborta el proceso:
      `TX11Console.Open` lanza `TPTCError` dentro del hilo de ptc, el `Execute`
      del wrapper solo tiene `try..finally` y `TPTCError` no desciende de
      `Exception`. Capturar el error de `Open` en `ProcessRequests`, devolverlo
      al llamante y traducirlo a `_graphresult` en `ptc_InternalOpen`, para que
      el plugin devuelva `VPAG_ERR_VIDEO`. Sin esto la selección `auto` de la
      Fase 6 no puede caer de un backend a otro. — `ba141c2`. Cambio 2 de
      `VENDOR/ptc/ptcwrapper.pp` (captura en `ProcessRequests`, relanzado en
      el hilo llamante) y cambio 7 de `VENDOR/ptcgraph.pp`
      (`ptc_InternalOpen` pasa a función, `grError` + `VPALastOpenError`, y en
      biblioteca destruye el hilo recién creado para que no llegue a
      `dlclose`). Objetivo `nodisplay-test` (`TESTS/x11/nodisplay_test.lpr`).
- [x] **T5.6** — **Reescribir en el plugin lo que sobrevive de
      `UNIT/xfocus.pas`** (`BACKENDS/X11/vpagraph_x11_window.pas`): conexión X
      persistente propia (ptc no llama a `XInitThreads` y su hilo es dueño de
      su `Display`; el XID de la ventana es global al servidor y basta con él),
      cursor en blanco, foco de teclado, pantalla completa por
      `_NET_WM_STATE`, «puntero dentro» y modificadores. Sin `FindWin` por
      título: la ventana la da T5.3b. `UNIT/xfocus.pas` **no se toca**; lo
      elimina T6.8. — `921bb9f`. `GrabFocus` espera a que la ventana sea
      visible: `XSetInputFocus` sobre una no mapeada es `BadMatch` y el
      manejador por defecto de Xlib mata el proceso; el plugin no instala
      `XSetErrorHandler` (global al proceso, pisaría el de XShm de ptc).
- [x] **T5.7** — Implementar el bloque de ventana/foco/escala de la ABI (T2.10)
      sobre ese código. La interpretación de `VPA_SCALE` (incluida la heredada
      de 1..20 como multiplicador) **se queda en el núcleo** (T2.10 y T6.x): al
      plugin le llega `ScalePercent`, que traduce a `VPAForceScale`, y
      `Fullscreen`, que traduce al estado `_NET_WM_STATE_FULLSCREEN`.
      — `921bb9f`. Cambio 3 de `ptcwrapper.pp`: `ConsoleWidth`/`ConsoleHeight`
      para el mapeo consola ↔ superficie. `Resume` rehace foco y pantalla
      completa. Objetivo `window-test` (`TESTS/x11/window_test.lpr`).
- [x] **T5.8** — Implementar el bloque de teclado y ratón (T2.11). — `738f76b`.
      Objetivo `input-test` (`TESTS/x11/input_test.lpr`, con `xdotool`). Ojo
      para T6.7: ptc no emite evento por el **primer** movimiento del ratón,
      solo fija la posición previa. Desde este commit la interfaz rellena
      todas las casillas de la ABI v1 y el cargador del núcleo la acepta.
      *Aclaración (2026-09-16), a la luz de D-10, posterior a esta tarea:* el
      plugin **no usa `ptccrt` ni `ptcmouse`**; bombea
      `PTCWrapperObject.NextEvent` él mismo y convierte `IPTCKeyEvent` (código,
      `Unicode`, modificadores), `IPTCMouseEvent` y `IPTCCloseEvent` a
      `TVPAGraphEvent`, con `KeyCode` = código ptc tal cual. `PTCLastKbdFlags`,
      `PTCQuitNoSave` y la emulación por software del rango del ratón son
      semántica del núcleo y se reescriben en T6.6 y T6.7.
- [x] **T5.9** — **Resolver la cuestión de los hilos.** `ptcgraph` levanta un
      hilo para el bucle de eventos X11 y por eso `cthreads` va el primero en
      `VPA/VPA.PAS`. Al mudarse `ptcgraph` al `.so`, hay que determinar
      experimentalmente: (a) si el `.so` necesita su propio `cthreads`;
      (b) si el ejecutable puede prescindir de él; (c) cómo se comporta el
      gestor de hilos con dos RTL en el mismo proceso. **Documentar el
      resultado en `docs/threads-and-rtl.md` antes de seguir**: si esto se
      entiende mal, aparecerán cuelgues intermitentes imposibles de depurar.
      — `67d3d4d`. Resultado en `docs/threads-and-rtl.md`: interbloqueo
      determinista en `dlclose` (el hilo de ptc moría dentro de la
      `finalization` del `.so`), resuelto haciendo que el hilo viva entre
      `Init` y `Shutdown` (cambio 6 de `ptcgraph.pp`, solo con `IsLibrary`);
      `dlopen` ya no necesita sesión gráfica; el RTL del `.so` no instala
      manejadores de señales, así que los `try..except` de los adaptadores
      solo cubren excepciones software. Objetivo `threads-test` del `Makefile`.
- [x] **T5.10** — Verificar aislamiento de dependencias:
      `ldd build/plugins/libvpagraph-x11.so` muestra `libX11`;
      `readelf -d build/VPA` no. — `d7c6fc0`. Objetivo `deps-test`; hasta la
      Fase 6 el ejecutable sigue enlazando X11, así que el `readelf` se hace
      sobre `scene_test_plugin`, el arnés que carga el `.so` con el cargador
      real.
- [x] **T5.11** — Arnés de prueba `TESTS/x11/scene_test.lpr`: dibuja las escenas
      geométricas básicas a través del plugin y vuelca el framebuffer. Comparar
      con el mismo programa llamando directamente a `ptcgraph`. **Debe dar cero
      píxeles de diferencia.** — `d7c6fc0`. Objetivo `scene-test`: cinco
      escenas (líneas, formas, texto con `LITT_VPA.CHR`, imágenes, paleta),
      10 ficheros de volcado idénticos byte a byte entre `scene_test_plugin`
      (cargador real) y `scene_test_direct` (`-dDIRECT`, `ptcgraph` del
      ejecutable con adaptadores propios).

**Criterio de aceptación:** `scene_test` a través del plugin es idéntico a
`scene_test` directo; el `.so` enlaza X11 y el arnés que lo carga, no.

> **Fase cerrada el 2026-09-16.** Verificado: `scene-test` 10/10 idénticos,
> `deps-test`, `threads-test`, `nodisplay-test`, `window-test` e `input-test`
> en PASS sin fugas; `make build` con los mismos 24 avisos y las 20 escenas
> doradas recapturadas coinciden con `TESTS/golden/SHA256SUMS` (el cambio 7
> de `ptcgraph.pp` también lo enlaza el ejecutable). El ejecutable no se ha
> tocado: `VPA/`, `UNIT/` y `vpa.cfg` siguen como en `fd384ad`.

---

### Fase 6 — Migración de VPA-Linux a `VPAGraph` 🔒

Aquí está el truco que hace viable toda la operación.

> **Decisión de diseño:** `GRAPH/vpagraph.pas` expone procedimientos con los
> **mismos nombres y las mismas firmas** que `ptcgraph` (mismos tipos:
> `smallint`, `ColorType`, shortstring), y reexporta sus constantes y tipos. Así
> la migración de las 24 unidades es **cambiar una palabra en la cláusula
> `uses`**, no reescribir 1195 llamadas a `OutTextXY` ni 706 a `SetColor`. El
> diff de esta fase debe ser de unas 30 líneas en total, más la unidad nueva.

- [x] **T6.1** — Escribir `GRAPH/vpagraph.pas` con la API pública completa:
      firmas idénticas a `ptcgraph`, reexportación de constantes y tipos (T1.2),
      conversión de cadenas, y redirección a la tabla de funciones del backend.
      — `100674a`, `5ed871e`. La terna `RestoreCrtMode` / `SetGraphMode` /
      `GetGraphMode` se reexporta sobre `Suspend`/`Resume` (D-08). Con el
      backend sin cargar las primitivas son inocuas. La lógica de `VPA_SCALE`
      (`xfocus.ResolveScale`) vive ya en el núcleo y pregunta el tamaño de
      pantalla al backend; `fullscreen` viaja como bandera de `Init`.
- [x] **T6.2** — Comprobar que `VPAGraph` es consumible desde `-Mtp`
      compilando una unidad de prueba mínima antes de tocar nada real. —
      `100674a`. `TESTS/vpagraph/graphapi_test.pas`, objetivo `graphapi-test`:
      un fuente `-Mtp` compilado dos veces con **una palabra** de diferencia en
      su `uses` (`vpagraph` / `ptcgraph`); 10 volcados idénticos byte a byte,
      y la variante del núcleo no enlaza `libX11` ni `libpthread`.
- [x] **T6.3** — Inicialización: `InitGraph` de `VPAGraph` detecta, carga y
      valida el backend antes de delegar. `CloseGraph` descarga el plugin. —
      `26e5985`. Objetivo `initgraph-test`: respaldo solo en `auto` (y `Init`
      cuenta como fallo), sin respaldo si es forzado, todos los motivos en
      `VPAGraphInitDetail`, ciclo repetible, sin fugas.
- [x] **T6.4** — Añadir `-FuGRAPH` y `-FiGRAPH` a `vpa.cfg`. — `ad0ba5c`
      Adelantado a la Fase 4: `VPA.PAS` ya consume `vpagraph_info`.
- [x] **T6.5** — Sustituir `ptcgraph` por `VPAGraph` en las 24 unidades, **una
      por commit o en grupos pequeños y coherentes**, verificando compilación
      tras cada grupo. — `8aecb96`. Hecho en **un solo commit** junto con
      T6.6–T6.9, por lo explicado abajo en «Orden de trabajo». Fueron 26
      unidades: las 24 de la lista más `CC/MSGWIN.PAS` y `CC/VPACC.PAS`, que el
      inventario no recogía.

  > **Ensayo hecho (2026-09-18, `5ed871e`):** en una copia desechable, cambiar
  > la palabra en todas las unidades enlazadas compila y enlaza el ejecutable
  > entero con **una sola línea borrada** (la asignación de
  > `ptcgraph.VPAForceScale` en `VPAINIT.PAS:1394`). D-03 se sostiene.
  >
  > **Orden de trabajo:** un ejecutable a medio migrar compila pero **no
  > funciona**: los gráficos irían por el plugin y el teclado (`ptccrt`)
  > seguiría esperando teclas de una consola ptc del ejecutable que ya nadie
  > abre. T6.5–T6.8 solo son coherentes en ejecución cuando están las cuatro.
  > Por eso se hace **antes** la parte del núcleo de T6.6/T6.7 (traducción de
  > teclas y búfer, D-10; estado del ratón), probada con arnés y `xdotool`
  > sin tocar el ejecutable, y **después**, en una misma sesión, el cambio de
  > `uses`, `KEYBOARD.PAS`, `MOUSE.PAS` y `xfocus`, cerrando con las escenas
  > doradas (T6.13). Así `feature/wayland` nunca queda en un commit que no
  > arranca.
  >
  > **Paso 1 hecho (2026-09-18):** `GRAPH/vpagraph_input.pas` y el objetivo
  > `coreinput-test`. El ejecutable sigue sin tocar. Lo que el paso 2 tiene
  > que saber de esa unidad:
  >
  > - Nombres con prefijo, para no chocar con los `KeyPressed`/`ReadKey`/
  >   `ShowMouse` que ya declaran `KEYBOARD.PAS` y `MOUSE.PAS`:
  >   `VPAKeyPressed`, `VPAReadKey` (`#0` + scancode, como `ptccrt`),
  >   `VPALastKbdFlags`, `VPAQuitNoSave`, `VPAKbdModifiers` (sustituye a
  >   `xfocus.KbdModifiers`), `VPAGetMouseState`, `VPASetMousePos`,
  >   `VPAShowMouse(Show)` y `VPAMouseInside` (sustituye a
  >   `xfocus.PointerInsideWindow`, `VPA2.PAS:4078`). El ratón ya va en
  >   coordenadas de superficie: los dos `xfocus.Map*` de `MOUSE.PAS`
  >   desaparecen sin sustituto.
  > - Una sola bomba de eventos (`PollEvent` no filtra por tipo, a diferencia
  >   de `NextEvent` de ptc): la vacían tanto `VPAKeyPressed` como
  >   `VPAGetMouseState`, con `Present` delante; las teclas van a un búfer de
  >   256 y el ratón lo recuerda el plugin. Sondear el ratón no pierde teclas
  >   (comprobado).
  > - Sin backend activo —antes de `InitGraph`, tras `CloseGraph` o con la
  >   ventana **suspendida**— `VPAInputReady` es `False` y `VPAReadKey`
  >   devuelve `#0` **sin esperar**. `ptccrt` leía entonces de la terminal con
  >   `crt`: `KEYBOARD.PAS` tiene que decidir qué hace en ese caso (lo natural,
  >   `if VPAInputReady then … else crt.…`, porque `crt` no enlaza X11).
  > - El volcado de Ctrl-F12 (`$8A00`, T0.4) se queda en `KEYBOARD.PAS`, que
  >   pasa a llamar a `vpagraph.VPADumpFrame`.
  > - `vpagraph.pas` expone `VPAGraphActiveInterface` (la tabla del backend en
  >   uso, `nil` si no hay o está suspendido) y por eso lleva
  >   `vpagraph_loader` en el `uses` de su interfaz; no afecta a las unidades
  >   `-Mtp`, porque `uses` no es transitivo.

  - [x] `VPA/VPADATA.PAS`
  - [x] `VPA/SCREEN.PAS`
  - [x] `VPA/VPAINIT.PAS`
  - [x] `VPA/VPAEXIT.PAS`
  - [x] `VPA/VPA2.PAS`
  - [x] `VPA/VPA3.PAS`
  - [x] `VPA/VPA4.PAS`
  - [x] `VPA/INI.PAS`
  - [x] `VPA/CONFIG.PAS`
  - [x] `VPA/MESSAGES.PAS`
  - [x] `VPA/EXTFEAT.PAS`
  - [x] `VPA/TCOMBAT.PAS`
  - [x] `VPA/BUILDING.PAS`
  - [x] `VPA/TASKS.PAS`
  - [x] `VPA/PLANSIM.PAS`
  - [x] `VPA/REPORT.PAS`
  - [x] `VPA/SCORES.PAS`
  - [x] `VPA/SCRSAVER.PAS`
  - [x] `VPA/DETAILS.PAS`
  - [x] `VPA/VCS.PAS`
  - [x] `UNIT/VHLP.PAS`
  - [x] `UNIT/VHLPSHOW.PAS`
  - [x] `VHLP/VHLP.PAS` *(duplicado histórico de `UNIT/`; comprobar cuál gana
        según el orden de `-Fu` en `vpa.cfg` y decidir si procede unificarlos —
        tarea aparte, no mezclar con esta)*
  - [x] `VHLP/VHLPSHOW.PAS` *(ídem)*

- [x] **T6.6** — Reescribir `UNIT/KEYBOARD.PAS` contra la ABI en lugar de
      `ptccrt` + `xfocus`.
  - [x] Núcleo: traducción `VPAGK_*` + Unicode + modificadores → scancodes de
        Turbo Pascal y búfer de teclas en `GRAPH/vpagraph_input.pas` (D-10).
        Es la tabla `kmTP7` de `VENDOR/ptccrt.pp` —nadie asigna `KeyMode`— con
        los arreglos de VPA: F11/F12, Ctrl-Tab, Ctrl-↑/↓, Alt-flechas,
        Ctrl-+/- por carácter (D-09), botón [X] = Alt-X y Ctrl-Alt-X.
        Objetivo `coreinput-test`: un fuente `-Mtp` compilado sobre el núcleo y
        sobre `ptccrt`+`ptcmouse`, las mismas 203 órdenes de tecla de `xdotool` a
        los dos, y 215 lecturas (palabra de tecla, `LastKbdFlags`,
        `QuitNoSave`, ratón) **idénticas**; más las pruebas sintéticas de lo
        que `xdotool` no puede producir con el teclado `us` de Xvfb (el `+` de
        es/de/fr con tecla indefinida, búfer lleno, sin backend).
  - [x] `UNIT/KEYBOARD.PAS` sobre `vpagraph_input` (paso 2). — `8aecb96`. Sin
        backend activo cae a `crt`, igual que hacía `ptccrt` (que ya lo
        enlazaba e inicializaba: la terminal se comporta como antes).
- [x] **T6.7** — Reescribir `UNIT/MOUSE.PAS` contra la ABI en lugar de
      `ptcmouse` + `xfocus`.
  - [x] Núcleo: estado del ratón sobre `PollEvent`/`GetMouseState`, con
        `Present` antes de sondear, en la misma unidad y con la misma prueba
        (movimiento, arrastre, los tres botones, y que sondear el ratón no se
        come las teclas).
  - [x] `UNIT/MOUSE.PAS` sobre `vpagraph_input` (paso 2). El rango por
        software y el despacho de manejadores se quedan como están. —
        `8aecb96`. Nuevo `Mouse.PointerInsideWindow` (envuelve
        `VPAMouseInside`) para que `VPA2.PAS` siga hablando con `Mouse` y no
        con el núcleo.
- [x] **T6.8** — Sustituir las 19 llamadas a `xfocus` (sección 2.1) por llamadas
      a `VPAGraph`, y **eliminar `UNIT/xfocus.pas`** del ejecutable. —
      `8aecb96`. La mayoría desaparecen **sin sustituto**: foco, escalado del
      ratón y pantalla completa los pone el plugin en `Init` y en `Resume`, así
      que sobra el ritual de tres líneas tras `OpenGraph` y tras cada
      `SetGraphMode(GetGraphMode)` de `INI.PAS`, y el `ReleaseFullscreen` de
      `CloseGraphics`. Comprobado en vivo: ciclo Ctrl-O → «Edit file» → editor →
      vuelta, volcados idénticos byte a byte a los del binario de `dc27c73` y
      teclado vivo sin que nadie devuelva el foco desde fuera. `GrErr` imprime
      `VPAGraphInitDetail`. `vpa.cfg` pierde `-FuVENDOR`, `-Fubuild/ptcunits` y
      `-FiVENDOR`.
- [x] **T6.9** — Revisar el `uses` de `VPA/VPA.PAS` a la luz de T5.9. —
      `8aecb96`. `cthreads` y `xfocus` fuera; queda `vpagraph_info`.
- [x] **T6.10** — `VHLP/VHLPMAKE.PAS` también enlaza la unidad gráfica (por eso
      el `Makefile` lo ejecuta con `xvfb-run`): decidir si pasa por `VPAGraph` o
      si se queda con `ptcgraph` como herramienta interna de compilación. La
      segunda opción es más simple y no compromete el objetivo, porque no forma
      parte del binario distribuido. — `f868923`. Ninguna de las dos: comparte
      la unidad `VHLP` con VPA, así que pasa por `VPAGraph` sola, y como nunca
      llama a `InitGraph` no abre ventana ni carga plugin. Se le quita
      `cthreads` y **`make hlp` ya no necesita `xvfb-run`**. Los dos `.HLP`,
      idénticos byte a byte.
- [x] **T6.11** — Verificación final: `grep -rn "ptcgraph\|ptccrt\|ptcmouse\|xlib"
      VPA/ UNIT/ CC/` no devuelve nada fuera de comentarios históricos. — 9
      líneas, todas comentarios (formato de imagen de ptcgraph y notas de esta
      migración).
- [x] **T6.12** — `readelf -d build/VPA | grep NEEDED` comparado con la línea
      base de T0.3: `libX11` y compañía han desaparecido. — Única entrada:
      `libc.so.6`.
- [x] **T6.13** — **Regresión completa**: reproducir las escenas de T0.5 y
      compararlas con las imágenes doradas de T0.6. Cero diferencias. —
      **40 de 40** ficheros de `TESTS/golden/SHA256SUMS` (20 `.ppm` + 20
      `.pal`) con `TESTS/capture.sh` y el `RESOURCE.PLN` real, en el contenedor.
      El binario de `dc27c73` da también 40 de 40 en el mismo entorno. Los once
      objetivos de prueba del `Makefile` pasan desde un `build/` limpio; las
      variantes «direct» salen ahora de `build/directunits` (objetivo
      `direct-units`), porque `make build` ya no deja los `.ppu` de ptcgraph.
- [x] **T6.14** — Partida real completa en X11: cargar una partida de
      `EXAMPLES/`, jugar un turno, guardar, salir y volver a entrar. Solo puede
      hacerse en la máquina de desarrollo. Mirar en especial lo que Xvfb sin
      gestor de ventanas no cubre: `VPA_SCALE=fullscreen` (entrar, «Edit file»
      y volver, salir: que el panel del escritorio reaparezca), el ratón con la
      ventana escalada, y el foco al volver del editor bajo Cinnamon. —
      Hecha por Pablo el 2026-09-19 en Arch/Cinnamon con el binario de
      `631ccdb` (`make data`, `readelf`: solo `libc.so.6`): en ventana normal y
      con `VPA_SCALE=fullscreen` entra y sale bien, y Ctrl-O → «Edit file»
      abre `nano` y al salir vuelve a la ventana de VPA con el foco. Con
      `VPA_SCALE=3` los clics del ratón caen donde toca, y se juega un turno,
      se sale y se vuelve a entrar con todo correcto. Las 20
      escenas doradas, recapturadas en esa máquina con su `RESOURCE.PLN`,
      dan 20 de 20 idénticas con `TESTS/compare.py` (tolerancia 0).

> **Pendiente para la Fase 12 (documentación):** `BUILD.es.md`/`BUILD.en.md` y
> los README siguen diciendo que `make hlp` necesita `xvfb`, que `cthreads` va
> primero en `VPA.PAS` y que el binario enlaza X11; y no dicen que `VPA`
> necesita su carpeta `plugins/` al lado (`make data` ya la empaqueta).

**Criterio de aceptación:** VPA funciona en X11 exactamente igual que 3.67.6, el
binario no enlaza X11, y las imágenes doradas coinciden píxel a píxel.

> **Fase cerrada el 2026-09-19.** Verificado: 40 de 40 doradas en el
> contenedor y 20 de 20 `.ppm` en la máquina de desarrollo, los once objetivos
> de prueba en PASS, `readelf` con `libc.so.6` como única dependencia, y la
> partida real de T6.14 en Arch/Cinnamon, en ventana y a pantalla completa.

> En este punto la arquitectura está completa y **no se ha escrito ni una línea
> de Wayland**. Buen momento para fusionar a `main` y, si se quiere, publicar
> una versión intermedia: aporta la arquitectura de plugins sin riesgo añadido.

---

### Fase 7 — Decisión: motor de dibujo del plugin Wayland 🔒

Prototipos acotados en tiempo, para decidir con datos en vez de con intuición.
**Este código es desechable y no se integra.**

- [x] **T7.1** — Fijar la versión de SDL3 objetivo y vendorizar los enlaces
      Pascal de `PascalGameDevelopment/SDL3-for-Pascal` en `VENDOR/sdl3/`
      (licencia MPL-2.0 / zlib, compatible con la del port). Anotar versión
      exacta y fecha. — f8307a9, 928ac44
      Enlaces `v0.6` (commit `8e9795000d3d`, 2026-05-05) → **SDL 3.4.4** como
      mínima. La licencia de los enlaces es solo zlib. Hubo que quitarles un
      `uses X, XLib` que metía `libX11` en todo lo que usara SDL3.
- [x] **T7.2** — Prototipo mínimo de SDL3 en Free Pascal: abrir ventana en
      Wayland, subir una textura de 640×480 y presentarla. Sin ABI, sin plugin,
      sin nada. Solo confirmar que la cadena FPC → enlaces → SDL3 → Wayland
      funciona en la máquina de desarrollo. — 06dfbd0
- [x] **T7.3** — **Prototipo de la vía B**: esqueleto de una consola PTC sobre
      SDL3 en `VENDOR/ptc/sdl/`. No tiene que funcionar; tiene que responder a
      tres preguntas: ¿cuántos métodos de `IPTCConsole` hay que implementar de
      verdad?, ¿hace falta tocar `ptcwrapper` (que **no** está vendorizado, viene
      de `fp-units-gfx`)?, ¿cómo encaja en `TPTCConsoleFactory`? — b163699, adb529a
- [x] **T7.4** — **Prototipo de la vía A**: implementar sobre SDL3 solo
      `Line` con `SetLineStyle` y `SetWriteMode(XORPut)`, y comparar píxel a
      píxel con `ptcgraph` usando `TESTS/compare.py`. Es la prueba de fuego: si
      reproducir *una* primitiva ya cuesta ajustes de trazado, reproducir las
      veinte y las fuentes `.CHR` es un proyecto en sí mismo. — fa36a85
- [x] **T7.5** — Escribir `docs/adr-001-motor-wayland.md`: opciones, medidas
      obtenidas en T7.3 y T7.4, decisión y motivos. Registrarlo también en la
      sección 8 de este documento. — a2fd358
- [x] **T7.6** — Marcar en la Fase 8 la vía descartada como `- [-]`, con el
      motivo. No se borra.

**Cierre (2026-09-19): vía B.** Medido en contenedor (Ubuntu 24.04, SDL 3.4.4
compilada desde fuente, `weston --backend=headless`, sin `DISPLAY`); todo se
repite con `TESTS/fase7/medir.sh`. Vía B: consola SDL3 de 536 líneas que
funciona, `ptcwrapper` y `ptcgraph` sin tocar, 10 de 10 volcados idénticos a
X11 y cuadros presentados idénticos a los volcados. Vía A: `Line` pasó de
10 054 píxeles distintos a 0 solo transcribiendo `graph.inc`/`clip.inc`.
Detalle en `docs/adr-001-motor-wayland.md`. Los prototipos de `TESTS/fase7/`
son desechables; la consola de `VENDOR/ptc/sdl/` es el punto de partida de la
Fase 8, inerte sin `-dPTC_SDL3` (X11 comprobado: `scene-test` y 20/20 doradas).
Queda fuera de lo medido un compositor real (KWin/Mutter): es T8B.0.

**Criterio de aceptación:** decisión tomada, escrita y justificada con
mediciones, no con preferencias.

---

### Fase 8 — Motor de dibujo Wayland 🔒

Se ejecuta **una** de las dos vías. La otra queda documentada como descartada.

#### Vía B — Consola PTC sobre SDL3 *(elegida, ADR-001)*

- [x] **T8B.0** — Repetir `TESTS/fase7/medir.sh` en un compositor real (la VM
      Slackware/KDE-Wayland y, si se puede, Arch) con la `sdl3` de la
      distribución. La Fase 7 solo se midió bajo `weston` sin pantalla.
      *Hecho el 2026-09-19 en la VM Slackware/KDE-Wayland (KWin, sesión real,
      `env -u DISPLAY`), con la `sdl3` **3.4.16** de la distribución contra
      enlaces 3.4.4 (D-20 funciona en la práctica): T7.2 `controlador wayland`,
      0 píxeles distintos al releer; vía B `scene_test: PASS` y los **10
      volcados con el mismo SHA-256** que la referencia X11 del contenedor.
      La VM no tiene 3D (VMware): Mesa avisa y el renderizador `opengl` cae a
      software, sin consecuencias. Pendiente menor: la misma medida en Arch.*
- [x] **T8B.1** — Vendorizar las piezas de PTCPas que falten (`ptcwrapper` y lo
      que T7.3 haya identificado), con el aviso de modificación que exige la
      LGPL, igual que ya se hizo en `VENDOR/ptcgraph.pp`.
      *No faltaba ninguna pieza (`ptcwrapper` ya estaba vendorizado desde D-18
      y no hace falta tocarlo). Faltaba el aviso de modificación en
      `VENDOR/ptc/ptc.pp`, que ahora enumera los cuatro cambios de VPA-Linux.*
- [x] **T8B.2** — `VENDOR/ptc/sdl/sdlconsoled.inc` y `sdlconsolei.inc`:
      declaración e implementación de la consola SDL3.
      *Revisado lo que el prototipo dejó vacío (`a16e742`): cursor en diana
      (el mismo dibujo 15×15 que en X11, con `SDL_CreateCursor`, escalado
      según el tamaño real de la imagen en la ventana y rehecho al
      redimensionar), opciones `show cursor`/`hide cursor`, `Save`, `Clear`
      con color y área, y `Copy`. El volcado de cuadros presentados **se
      queda** como instrumento para la Fase 11, renombrado a
      `VPA_GRAPH_PRESENTED`. Además: `MoveMouseTo` (R12, `c15c869`) y
      `SDL_HINT_NO_SIGNAL_HANDLERS`, porque SDL convertía SIGTERM en «cerrar
      ventana» y un `kill` fuera del mapa no mataba a VPA. Prueba:
      `TESTS/wayland/console_test.lpr`, dentro de `make wayland-test`.*
      *Diferencia conocida, del compositor y no de VPA (KWin 6.7.5): al sacar
      el puntero de la ventana directamente al fondo del escritorio de Plasma
      se sigue viendo la diana, porque el escritorio no fija cursor y KWin
      deja el último; sobre otra ventana o la barra de tareas sale el del
      sistema. En X11 la ventana raíz tiene cursor propio. Sin arreglo
      posible desde el cliente.*
- [x] **T8B.3** — Apertura de ventana: `SDL_Init(VIDEO)` con el controlador de
      vídeo forzado a `wayland` (hint de SDL3, no solo la variable de entorno),
      ventana redimensionable, textura de presentación en streaming.
- [x] **T8B.4** — Superficie lógica indexada de 8 bits y ciclo
      `Lock` / `Unlock` / `Update`, conservando la semántica de PTC.
- [x] **T8B.5** — Conversión indexado → 32 bits en la presentación, respetando
      la ruta de paleta existente.
- [x] **T8B.6** — Presentación con **filtrado de vecino más próximo**: la
      ventana actual escala con bordes nítidos y el aspecto tiene que ser el
      mismo. Nada de suavizado.
- [x] **T8B.7** — Cola de eventos: traducir eventos SDL3 a eventos PTC
      (`IPTCKeyEvent`, `IPTCMouseEvent`, `IPTCCloseEvent`), que es lo que hace
      que `ptccrt` y `ptcmouse` funcionen sin tocarlos.
      *Hecho (2026-09-20): ratón y cierre estaban desde la Fase 8; el teclado
      completo es T9.1/T9.2.*
- [x] **T8B.8** — Registrar la consola en `TPTCConsoleFactory` mediante un
      define de compilación, de modo que la misma base de PTC produzca la
      consola X11 o la SDL según cómo se compile el plugin.
- [x] **T8B.9** — Construir `libvpagraph-wayland.so` reutilizando el adaptador
      de ABI de la Fase 5 (idealmente **el mismo fichero**, compilado dos veces
      con distinto define: si el adaptador es común, la equivalencia entre
      backends deja de ser una esperanza y pasa a ser una propiedad del código).
      *Hecho así: `BACKENDS/WAYLAND/vpagraph_wayland.lpr` compila
      `BACKENDS/X11/vpagraph_x11_impl.pas` y `vpagraph_x11_input.pas` con
      `-dVPAG_WAYLAND`; lo único propio es `vpagraph_wayland_window.pas`
      (D-22). `make wayland-plugin` (opcional hasta la Fase 12: `make build`
      no exige SDL3). El `.so` enlaza `libSDL3` y no `libX11`.*
- [x] **T8B.10** — Comparación píxel a píxel contra las imágenes doradas.
      Objetivo realista aquí: **cero diferencias**.
      *A medias: `make wayland-test` (weston sin pantalla, sin `DISPLAY`) da
      cero diferencias en las 5 escenas por el plugin y en los 10 volcados de
      `graphapi-test` por el núcleo con `VPA_GRAPH_BACKEND=wayland`; además
      2×20 ciclos Init/Shutdown + `dlclose` sin fugas y `VPAG_ERR_VIDEO` con
      mensaje cuando no hay compositor.*
      *Doradas de la partida real (2026-09-19): `VPA_CAPTURE=wayland
      TESTS/capture.sh` (sway sin pantalla + `wtype`; weston no permite
      inyectar entrada) da **20 de 20 idénticas** a la referencia X11 del
      contenedor, que a su vez coincide con `TESTS/golden/SHA256SUMS`.*
      *Las 4 que fallaban en la primera pasada eran del **arnés**, no del
      backend (diagnosticado con `SDL_EVENT_LOGGING=2` y `WAYLAND_DEBUG=1`):
      (a) E06, E07 y E17: un sway sin dispositivos no anuncia puntero en el
      `wl_seat`, y `wlrctl` crea y destruye su puntero virtual en la misma
      invocación, antes de que SDL llegue a enlazar `wl_pointer`: a VPA no le
      llegaba ni un `motion`. Ahora `TESTS/wayland/hold-pointer.py` mantiene un
      puntero virtual vivo toda la captura y los movimientos son absolutos,
      con `swaymsg seat seat0 cursor set X Y` (`wlrctl` ya no hace falta).
      (b) E03: `ctrl+Tab` llegaba bien; la diferencia venía de que `Zoom` mueve
      el puntero (`MoveMouseTo`), SDL da el salto por hecho con un `motion`
      sintético, el sway 1.9 del contenedor no aplica la pista de
      `zwp_locked_pointer_v1` y su cursor seguía en (240,240), así que el
      aparcado final en (240,240) no emitía nada. El arnés mueve ahora en dos
      pasos para que siempre haya `motion`. Ver R12.*

#### Vía A — Reimplementación BGI sobre SDL3 *(descartada, ADR-001)*

> **Descartada el 2026-09-19 (D-06, `docs/adr-001-motor-wayland.md`).** T7.4
> demostró que converge, pero solo copiando `graph.inc` manía a manía: es
> reescribir a mano lo que la vía B reutiliza. Se conserva como contingencia.

- [-] **T8A.1** — Framebuffer indexado de 8 bits, paleta y presentación SDL3.
- [-] **T8A.2** — Estado gráfico: color, color de fondo, estilo de línea,
      estilo de relleno, modo de escritura, viewport, posición actual.
- [-] **T8A.3** — Primitivas: `PutPixel`, `GetPixel`, `Line` (con estilo y
      grosor), `LineTo`, `LineRel`, `MoveTo`, `Rectangle`, `Bar`, `Circle`,
      `Ellipse`. Solo las del inventario real.
- [-] **T8A.4** — Recorte y viewport con la semántica exacta de BGI.
- [-] **T8A.5** — Modos de escritura, empezando por `XORPut` (36 usos).
- [-] **T8A.6** — Paleta: `SetRGBPalette`, `GetRGBPalette` y la conversión de
      T1.7.
- [-] **T8A.7** — Imágenes: `ImageSize`, `GetImage`, `PutImage` con el formato
      exacto de T1.6, incluidos los buffers construidos a mano por `TCOMBAT` y
      `EXTFEAT`.
- [-] **T8A.8** — Texto: fuente bitmap 8×8 (`DefaultFont`), cargador y
      rasterizador de `.CHR` (`LittFont`), justificación, `TextWidth`,
      `TextHeight`. La parte más ingrata y la que más se nota si falla.
- [-] **T8A.9** — Comparación píxel a píxel e iteración hasta converger.
      Documentar y justificar cada diferencia que se decida tolerar.

**Criterio de aceptación:** `env -u DISPLAY VPA_GRAPH_BACKEND=wayland` abre
ventana y dibuja las escenas de referencia con el resultado acordado en la vía
elegida.

---

### Fase 9 — Eventos: teclado, ratón y cierre de ventana 🔒

Con la vía B esta fase es pequeña (la consola ya entrega eventos y `ptccrt` /
`ptcmouse` los consumen). Con la vía A hay que hacerla entera.

- [x] **T9.1** — Tabla de traducción de teclas SDL3 → códigos que espera
      `UNIT/KEYBOARD.PAS`: teclas extendidas, función, cursores, `Ctrl`+letra,
      `Alt`+letra.
      *Hecho: `SDLKeycodeToPTC` y `SDLNumPadToPTC` en
      `VENDOR/ptc/sdl/sdlconsolei.inc` cubren las mismas teclas que
      `FNormalKeys`/`FFunctionKeys` de la consola X11, con las mismas banderas
      (`pmkNumPadKey`, `pmkRightKey`, bloqueos). El teclado numérico va por
      scancode y estado de BloqNum (`PTCKEY_NUMPADn` + dígito, o la tecla de
      cursor), como `XK_KP_1`/`XK_KP_End`. Una tecla sin código PTC se entrega
      con `PTCKEY_UNDEFINED` y su carácter, igual que X11 (el prototipo la
      tiraba).*
      *Teclado numérico sin BloqNum en KWin (2026-09-20), **cerrado, no era de
      VPA**: en la primera prueba de Pablo (KWin 6.7.5, VM VirtualBox) 8/4/6/2
      con BloqNum apagado no movían la diana y con el plugin X11 sí. Su traza
      `VPA_KEY_TRACE=1` muestra que SDL entrega lo correcto: el 8 del teclado
      numérico (scancode 96, `mod=$0000`) sale como `code=38` (`PTCKEY_UP`),
      `uni=0`, igual que la flecha (scancode 82) salvo `numpad=TRUE`, y
      4/6/2 como 37/39/40; con BloqNum encendido (`mod=$1000`) el 8 sale
      `code=104 uni=56`. `ptccrt` convierte las dos en el mismo `#0#72`. La
      diferencia era otra vez el ratón absoluto de la VM (R12): esas teclas
      mueven la diana con un warp, y con la integración del ratón de
      VirtualBox el anfitrión lo deshace. Con la VM capturando el ratón
      (puntero relativo) 8/4/6/2 mueven la diana píxel a píxel, y el foco y
      el imán siguen bien. La traza `VPA_KEY_TRACE=1` se queda como ayuda de
      diagnóstico.*
- [x] **T9.2** — **Entrada de texto para distribuciones no estadounidenses.**
      `Ctrl-+` y `Ctrl--` se arreglaron en 3.67.5 comparando el carácter
      Unicode, no el scancode. En SDL3 hay que combinar el evento de tecla con
      el de entrada de texto y rellenar `UnicodeChar` en `TVPAGraphEvent`.
      Probar explícitamente con distribución española y con la rusa, que es la
      de Alexander.
      *Hecho, pero **sin** `SDL_EVENT_TEXT_INPUT` (D-23): el carácter sale de
      `SDL_GetKeyFromScancode(scancode, mod, False)`, el mapa que SDL construye
      del keymap xkb del compositor. Probado en `make wayland-input-test` con
      `TESTS/wayland/vkbd.py` (teclado virtual con la distribución de verdad):
      `us` (Ctrl-Shift-= → «+»), `es` («+» como tecla propia, sin código PTC;
      «-» en la tecla del «/»; Shift-7 → «/» con código `PTCKEY_SLASH`;
      AltGr-2 → «@») y `ru` sin grupo latino (Alt-X conserva el código de la
      X gracias a la opción `latin_letters` de SDL, activa por defecto, y el
      carácter es el cirílico; Ctrl-+ y Ctrl-- llegan). Mejora sobre X11: con
      `ru` activa la consola X11 entrega las letras con `PTCKEY_UNDEFINED`.*
- [x] **T9.3** — Modificadores (`Shift`/`Ctrl`/`Alt`) en el formato heredado
      estilo BIOS `0040:0017` que devuelve hoy `xfocus.KbdModifiers`.
      *Hecho: `CurrentModifiers` del plugin lee `ptc.PTCSDLInputState` (D-24).
      Wayland solo informa de modificadores a la ventana con foco: sin foco,
      «ninguno».*
- [x] **T9.4** — Ratón: posición, botones, movimiento, y la emulación de
      `StickyMouseRange`.
      *Hecho: posición, botones izquierdo/derecho e `Inside`
      (`PointerInsideWindow`, D-24) probados en `wayland-input-test`. El imán
      funciona en KWin 6.7.5 (prueba de Pablo, 2026-09-20, con el ratón
      relativo de la VM; ver R12).*
- [x] **T9.5** — Ocultar el cursor del sistema dentro de la ventana, como hace
      hoy `xfocus` con un cursor en blanco.
      *Hecho en la Fase 8 (T8B.2): diana propia de la consola y opciones
      `show cursor`/`hide cursor`.*
- [x] **T9.6** — Cierre de ventana: mapearlo al camino existente
      (`PTCQuitNoSave` / emulación de `Ctrl-C`) para que el guardado de
      emergencia de `VPA/VPAEXIT.PAS` siga funcionando. **Probar con una partida
      con cambios sin guardar**: es justamente el caso en que un fallo aquí
      duele de verdad.
      *Hecho: `xdg_toplevel.close` llega como `CLOSE` (`wayland-input-test`) y
      de ahí en adelante el camino es el de `ptccrt`, común con X11 ([X] =
      Alt-X, salir guardando). Probado por Pablo en KWin 6.7.5 (2026-09-20):
      cambia un código de amistad, cierra con [X] y al volver a abrir el
      cambio está guardado y hay un TRN nuevo.*
- [x] **T9.7** — Foco de teclado al abrir y al volver del editor externo
      (`$VISUAL`/`$EDITOR`, arreglado en 3.67.5).
      *Probado por Pablo en KWin 6.7.5 (2026-09-20): VPA responde a la primera
      tecla nada más abrir (F1, F3) y recupera el foco al volver de «Edit
      file» (Ctrl-O). De paso: al pasar la diana al fondo del escritorio ya
      sale el puntero del sistema sin tener que pasar por otra ventana (el
      cosmético anotado en la Fase 8, resuelto por D-24).*
- [x] **T9.8** — Repetición de teclas y latencia comparadas con X11.
      *Probado por Pablo en KWin 6.7.5 (2026-09-20): con una flecha mantenida
      la diana se mueve bien y se para en seco al soltar; Tab/Ctrl-Tab, F11,
      Ctrl-+/Ctrl-- (fila principal y teclado numérico, distribución
      española real) y los caracteres `@~/().` en un mensaje, sin diferencias
      con X11.*
      *De la revisión del camino de las flechas: `MoveMouseTo` apuntaba al
      borde del píxel de consola y con escala no entera el `wl_fixed` del
      compositor lo devolvía en el píxel anterior; ahora apunta al centro.*

**Criterio de aceptación:** se puede jugar un turno completo en Wayland solo con
teclado y ratón, sin diferencias perceptibles respecto a X11.

---

### Fase 10 — Escalado, HiDPI y pantalla completa 🔒

- [x] **T10.1** — Implementar `ResolveScale` para Wayland respetando la
      semántica completa de `VPA_SCALE` (sección 2.3.10), obteniendo el tamaño
      de pantalla de SDL3 en lugar de Xlib.
      *Hecho (D-25). `ResolveScale` ya era del núcleo (`GRAPH/vpagraph.pas`) y
      común a los dos backends; lo que faltaba era que el plugin Wayland
      contestase `GetScreenSize`, que se llama **antes** de `Init`. Sin ese
      dato `VPA_SCALE=fullscreen` pedía el 800 % (una consola de 5120×3840
      que SDL luego reducía) y un `VPA_SCALE` grande no se recortaba. Ahora
      `ptc.PTCSDLScreenSize` da la pantalla primaria en unidades lógicas.
      Probado en `make wayland-input-test` (sway sin pantalla, salida de
      1600×1200): 1600×1200 antes de `Init`, 800×600 con la salida a ×2, y
      1600×1200 con la ventana abierta; y por el núcleo, con
      `VPA_GRAPH_DEBUG=1`: `VPA_SCALE=9` y `fullscreen` → 250 %, `2` y sin
      definir → 200 %. Falta verlo en una pantalla real (T10.7).*
- [x] **T10.2** — Presentación lógica de 640×480 con relación de aspecto
      preservada y bandas laterales cuando haga falta.
      *La presentación ya estaba desde la Fase 8
      (`SDL_SetRenderLogicalPresentation`, LETTERBOX, vecino más próximo).
      **Fallo encontrado y corregido:** un clic en una banda negra llegaba a
      VPA con X negativa y se veía como un clic en la columna 0 del mapa.
      Ahora `TSDLConsole.MouseAt` hace lo que la consola X11 en pantalla
      completa: de las bandas no sale nada, ni movimiento ni botones, y lo
      que cambie en los botones se entrega al volver a la imagen. Probado en
      `wayland-input-test` con una ventana de 1600×600. No se puede probar en
      el contenedor el botón mantenido que entra desde la banda (sway 1.9 no
      entrega `cursor set` con un botón pulsado).*
      *Segundo fallo, visto por Pablo en KWin (VM Slackware, 1920×1080, KDE al
      100 %, 150 % y 200 %): **las bandas eran transparentes**, en ventana y a
      pantalla completa se veía el escritorio por ellas. Causa en D-28.
      Corregido y **verificado por Pablo en KWin** (bandas negras en ventana
      y a pantalla completa). La prueba automática que lo cubría (fondo
      magenta de `swaybg` detrás de una ventana de 1600×600 y el píxel de la
      banda en la captura de `grim`: `ff00ff` antes, `000000` después) se
      retiró con D-29: la ventana flotante ya no tiene bandas, en mosaico SDL
      también la recorta, y a pantalla completa sway pinta negro debajo, de
      modo que en el contenedor una banda transparente no se distingue.*
      *Tercer fallo, también de Pablo en KWin: **al meter el puntero en la
      banda derecha el mapa hacía scroll sin parar**. El auto-scroll de VPA
      (`VPA2.PAS`) salta con `MouseX<8`, `MouseX>471`, `MouseY<8` o
      `MouseY>477` si el puntero está dentro de la ventana; en la banda VPA
      conserva la última posición entregada y `POINTER_INSIDE` solo miraba el
      foco de ratón de SDL. Por la derecha pasaba siempre (todo el panel,
      472..639, cumple `MouseX>471`); por la izquierda casi nunca. Ahora en
      una banda el puntero está **fuera** (`FInBand`), como al salir por el
      borde de la ventana en X11. Probado en `wayland-input-test` a pantalla
      completa (falla sin el arreglo). El scroll con el puntero parado en el
      panel derecho es de VPA (código de DOS, común a X11) y no se toca.
      **Confirmado por Pablo en KWin:** el mapa se para al entrar en
      cualquiera de las dos bandas.*
- [x] **T10.3** — Transformación de coordenadas del ratón de ventana física a
      superficie lógica (equivalentes de `MapMouseToSurface` y
      `MapSurfaceToWindow`), delegando en la conversión que ofrece SDL3 en lugar
      de repetir la aritmética a mano.
      *Hecho desde las fases 8 y 9 (`SDL_ConvertEventToRenderCoordinates` a
      la ida, `SDL_RenderCoordinatesToWindow` al centro del píxel a la
      vuelta). Probado en `wayland-input-test`: escala ×2, escala no entera
      (ida y vuelta de los 639 píxeles), letterbox lateral ((1000,450) →
      (480,360)), pantalla completa 16:9 y salida a ×2.*
- [x] **T10.4** — Pantalla completa: ~~`VPA_FULLSCREEN`, `VPA_VIDEO=fullscreen` y~~
      `VPA_SCALE=fullscreen`, con las tres rutas que hoy llaman a
      `RequestFullscreen`/`ReleaseFullscreen`.
      *`VPA_FULLSCREEN` y `VPA_VIDEO` retiradas de la tarea (D-27).
      Hecho en el contenedor, falta la prueba manual en KWin.
      `VPA_SCALE=fullscreen` funciona: el núcleo pone
      `Params.Fullscreen`, el plugin lo pide a la consola con `Option` (D-22) y
      lo rehace en cada `Resume` («Edit file»); con T10.1 la consola ya nace
      con el mayor 4:3 que cabe y no al 800 %. Probado en
      `wayland-input-test`: `SetFullscreen` en una salida de 1920×1080, centro
      y esquina exactos, nada desde las bandas, y vuelta a ventana. Las «tres
      rutas» son hoy `Params.Fullscreen` en `Init`, la reaplicación en
      `Resume` y `SetFullscreen` de la ABI.*
      *Probado por Pablo en KWin con KDE al 100 %, 150 % y 200 %: la imagen
      ocupa el mayor 4:3 (1440×1080 físicos en 1920×1080), los clics caen en
      su sitio y los de las bandas no hacen nada. Los dos fallos que salieron
      (bandas transparentes, scroll sin fin en la banda derecha) están en
      T10.2.*
- [x] **T10.5** — HiDPI: comprobar el comportamiento con factor de escala del
      compositor ≠ 1. Es el caso en el que Wayland difiere más de X11 y donde es
      más probable que el ratón se descuadre.
      *Hecho en el contenedor (D-26), falta verlo en una pantalla real. El
      ratón no se descuadra (SDL ya cuenta con la densidad). Lo que fallaba
      era la nitidez: sin `SDL_WINDOW_HIGH_PIXEL_DENSITY` SDL dibujaba a la
      resolución lógica y ampliaba el compositor; con rayas de 1 px y la
      salida a ×2 la captura de `grim` salía de un solo color. Con la bandera,
      las rayas sobreviven píxel a píxel (`TESTS/wayland/blur-check.py`).
      **A mirar en T10.7:** con el compositor a ×2 en 2560×1440 la pantalla
      lógica es 1280×720 y `VPA_SCALE` se recorta al 150 %, una escala no
      entera de ptc (columnas desiguales) que SDL luego dobla.*
      *Visto por Pablo en KWin (1920×1080) con KDE al 150 % y 200 %: nítido,
      sin interpolación, y el ratón marca los planetas correctos. El recorte
      da 150 % y 112 %, pero en píxeles físicos la imagen es la misma que al
      100 % (1440×1080, ×2,25): la escala de KDE no cambia el resultado, y
      las columnas desiguales de ×2,25 vienen de 1080/480, no de HiDPI.*
- [x] **T10.6** — Redimensionado de ventana en caliente sin perder el contenido.
      *Hecho desde la Fase 8: la textura es de la consola y SDL la vuelve a
      presentar en `WINDOW_EXPOSED`; la diana se rehace en `WINDOW_RESIZED`.
      `wayland-input-test` redimensiona cuatro veces (1087×816, 1600×600,
      640×480, 320×240) y sigue leyendo ratón e imagen correctos. Pablo ya
      lo vio en KWin en la Fase 8 (la diana se redimensiona con la ventana).*
- [x] **T10.7** — Probar en 2560×1440 (máquina de desarrollo) y en resoluciones
      pequeñas donde el escalado tenga que recortarse.
      *Hecho por Pablo en la VM de KWin cambiando su resolución (la máquina
      de desarrollo solo tiene X11, y a VPA le da igual de quién sea la
      pantalla): 2048×1152, la mayor que ofrecía la VM, y 800×600, donde
      `VPA_SCALE=2` se recorta. En las dos los clics caen en su sitio.
      Los logs dan lo calculado: 240 % en 2048×1152 (1152/480) y 125 % en
      800×600, tanto con `fullscreen` como con `VPA_SCALE=2` recortado.
      2560×1440 exactos quedan sin ver; no hay nada en el camino que dependa
      de esa cifra.*
- [x] **T10.8** — (añadida) La ventana flotante es siempre 4:3 (D-29). Pablo
      vio que `VPA_SCALE=9` en ventana dejaba bandas de 50 px: `ResolveScale`
      recorta contra la pantalla entera (Wayland no da el área útil) y KWin
      encoge la ventana para que quepan la barra de título y el panel
      (1440×1004). Con `SDL_SetWindowAspectRatio` SDL recorta el lado que
      sobra. Probado en `wayland-input-test`: a una ventana flotante se le
      conceden 1600×600 y se queda en 800×600, ratón exacto.
      **Confirmado por Pablo en KWin** (1920×1080, `VPA_SCALE=9`): la ventana
      sale sin franjas, mantiene 4:3 al estirar de un borde o de una esquina
      (lo que sway no dejaba probar), maximizada tiene bandas negras y al
      restaurar vuelve a 4:3.
      *Nota para quien lea un log con `VPA_GRAPH_DEBUG=1` en una VM sin 3D:
      los avisos `VMware: No 3D enabled` y `MESA-EGL: failed to create dri2
      screen` son de Mesa, que escribe en `stderr` al cargarse la biblioteca
      (por eso parten la línea `trying ...`). SDL dibuja entonces por
      software; no es un fallo.*

**Criterio de aceptación:** sin distorsión, ratón exacto en todas las escalas,
y comportamiento estable con HiDPI.
*Cumplido (2026-09-20). Sin distorsión: 4:3 siempre, en ventana por D-29 y
con bandas negras opacas en maximizada y pantalla completa (D-28). Ratón
exacto del 112 % al 240 %, en `wayland-input-test` y a mano en KWin. HiDPI:
KDE al 150 % y 200 %, nítido y sin descuadre (D-26). Queda sin ver una
pantalla de 2560×1440 exactos (T10.7).*

---

### Fase 11 — Comparación visual automatizada ⚡

- [x] **T11.1** — `TESTS/visual/run.sh`: ejecuta el catálogo de escenas de T0.5
      en los dos backends y vuelca los framebuffers. — 3d5a2a2
      Dirige lo que ya existía (`TESTS/capture.sh` con `VPA_CAPTURE=x11` y
      `wayland`); `make visual-test` compila lo necesario y lo lanza. No entra
      en `wayland-test` porque necesita la partida, las doradas y el
      `RESOURCE.PLN` real, que no están en el repositorio.
- [x] **T11.2** — Comparar contra las imágenes doradas y generar un informe
      (píxeles distintos, mapa de diferencias, veredicto). — 3d5a2a2
      `build/visual/informe.md` (procedencia, una fila por escena y backend,
      veredicto) más `diff-x11/` y `diff-wayland/` con el PNG de cada escena
      que no coincida. El guion se niega a comparar si las doradas locales no
      son las de `SHA256SUMS`. Probado también en negativo: con una dorada
      alterada en 50 píxeles da la caja exacta, el mapa y veredicto FALLA.
- [x] **T11.3** — Fijar el umbral de tolerancia. Con la vía B debería ser
      **cero**. Con la vía A, definir y **justificar por escrito** cada
      diferencia tolerada. — 3d5a2a2
      Es **cero**, y `run.sh` no tiene opción para subirlo. La única válvula es
      la lista de cajas por escena de `TESTS/excepciones.txt`, que sigue vacía.
- [x] **T11.4** — Añadir escenas específicas para lo que sabemos que es frágil:
      `XORPut` de las gomas elásticas, texto con `LittFont` en el mapa,
      `GetImage`/`PutImage` del visor de combate, viewport del panel derecho
      (el del desplazamiento de 32 píxeles de 3.67.5), paleta del gráfico de
      estadísticas (el del azul ilegible de 3.67.5). — 75071fc
      Cuatro de las cinco ya tenían escena desde T0.6: E17 (`XORPut`), E01–E03
      (`LittFont`), E14 (viewport) y E13 (paleta de estadísticas); `GetImage`/
      `PutImage` de fondo de menú, E10. Faltaba el combate: **E21** nueva, el
      simulador con nave y planeta, que pinta con `PutImage` las imágenes de
      casco construidas a mano (los mismos buffers que el visor). El **visor
      animado** queda descartado por escrito (`docs/reference-scenes.md`, 3.2):
      sale de `Randomize` (semilla del combate, imagen y textura del planeta,
      rayo que dispara) y es una animación con `Delay`; fijarlo pediría un
      gancho de semilla solo para pruebas, que es lo que prohíbe la regla 2.
      Sus modos de `PutImage` (`NormalPut`, `XORPut`, `OrPut`, recortado) ya
      los compara byte a byte `make wayland-test` (escena 4 de `scene_test`).
- [x] **T11.5** — Documentar cómo regenerar las imágenes doradas cuando un
      cambio *deliberado* las invalide, y la norma de que regenerarlas siempre
      es una decisión consciente que se anota, nunca un paso automático para
      que las pruebas dejen de quejarse. — de5873b
      En `TESTS/golden/README.md`: motivos legítimos y los que no lo son,
      procedimiento (dos pasadas idénticas, mirar el mapa de diferencias,
      siempre con X11, comprobar que en `SHA256SUMS` solo cambian las líneas
      esperadas), qué debe decir el commit y un registro de regeneraciones.
      Ningún guion ni objetivo del `Makefile` escribe en `TESTS/golden/`.

**Criterio de aceptación:** las pruebas visuales pasan en los dos backends y el
informe es reproducible.

**Verificado (2026-09-20, contenedor):** antes de tocar nada, las 20 escenas
capturadas en X11 con la partida y el `RESOURCE.PLN` de Pablo dan los hashes de
`SHA256SUMS` del 2026-09-13, o sea que las doradas locales son las de entonces.
`TESTS/visual/run.sh` y, aparte, `make visual-test` completo: las dos pasadas
dan **42 de 42 idénticas** (21 escenas, X11 y Wayland); unos 3 minutos y medio
por pasada. Después, `make wayland-test` entero pasa con el `Makefile` nuevo.

**Verificado por Pablo (2026-09-20, `pc-arch`, solo X11):** `sha256sum -c` de
las doradas sin quejas y `VPA_VISUAL_BACKENDS=x11 TESTS/visual/run.sh` con
**21 de 21 idénticas**: E21, dorada en el contenedor, sale igual en Arch.

---

### Fase 12 — Empaquetado, documentación y publicación 🔒

- [ ] **T12.1** — `make data` copia también `build/plugins/*.so` al paquete
      distribuible, y `VPA` los encuentra al ejecutarse desde el directorio de
      juego (regla 2 de T3.2).
- [ ] **T12.2** — Definir la distribución instalada: binario en `bin/`, plugins
      en `lib/vpa-linux/`. Documentar cómo se ajusta la ruta al compilar.
- [ ] **T12.3** — Compilación para aarch64 (Raspberry Pi) de los dos plugins, o
      decisión explícita y documentada de publicar solo el plugin X11 en esa
      arquitectura si SDL3 no está disponible.
- [ ] **T12.3b** — **Decidir si el paquete distribuible incluye su propia
      SDL3.** El problema es real: donde SDL3 no viene en la distribución,
      tampoco está en sus repositorios, y las tres máquinas que nos importan
      están en ese grupo (Kubuntu 24.04 LTS —Canonical no va a retroportarla,
      la 26.04 es la primera LTS que la trae—, Astra Linux, y Raspberry Pi OS
      sobre bookworm). Pedirle a un jugador que compile SDL3 para abrir VPA no
      es una opción realista. Como SDL está bajo licencia zlib, se puede
      **redistribuir `libSDL3.so.0` dentro del paquete**, junto a
      `libvpagraph-wayland.so`, y darle al plugin un `RPATH` de `$ORIGIN` para
      que encuentre su propia copia sin tocar el sistema. Tareas concretas:
      1. comprobar que `$ORIGIN` resuelve bien desde un plugin cargado con
         `dlopen` (no es lo mismo que desde el ejecutable);
      2. decidir si se publican dos tarballs (uno con SDL3 incluida y otro
         sin ella, para quien la tenga del sistema) o uno solo con la copia
         embebida como respaldo;
      3. fijar la versión exacta de SDL3 que se embarca (la misma de `T7.1`)
         y anotarla en las notas de publicación;
      4. incluir el fichero de licencia de SDL3 en el paquete.
      Esto es una decisión de empaquetado, no de arquitectura: no cambia nada
      de las fases 1 a 11.
- [ ] **T12.4** — Actualizar `BUILD.en.md` y `BUILD.es.md`: dependencias nuevas
      (SDL3 y sus cabeceras Pascal), objetivos nuevos del `Makefile`, cómo
      compilar solo un backend.
- [ ] **T12.5** — Actualizar `HOWTO.en.md` y `HOWTO.es.md`: `VPA_GRAPH_BACKEND`,
      `VPA_GRAPH_PLUGIN_DIR`, `--graph-info`, y qué hacer si falta SDL3.
- [ ] **T12.5b** — Documentar en los HOWTO las **tres vías para tener SDL3**, con
      ejemplos concretos y sin dar por hecho que la primera siempre sirve:
      1. **desde los repositorios**, donde la distribución la trae —Arch
         (`sdl3`), Slackware-current (serie `l/`, ya incluye SDL3 3.4.10),
         Debian testing/unstable y Ubuntu 25.10 en adelante
         (`libsdl3-0` / `libsdl3-dev`);
      2. **compilada a mano**, con las instrucciones mínimas de CMake para
         quien no la tenga en su distribución (es sencillo y SDL respeta la
         ABI dentro de la serie 3.x, pero es un obstáculo real para un usuario
         que solo quiere jugar);
      3. **la copia incluida en el paquete**, si `T12.3b` acaba en que se
         embarca.
      Y dejar dicho, con todas las letras, que **si no hay SDL3 por ninguna de
      las tres vías no pasa nada**: el plugin Wayland no carga, `auto` se queda
      en X11 y VPA funciona exactamente igual que hoy. Nadie se queda sin jugar
      por esto.
- [ ] **T12.6** — Actualizar `README.en.md` y `README.es.md` con la sección de
      arquitectura gráfica.
- [ ] **T12.7** — Añadir a `CHANGE.TXT` la entrada correspondiente.
- [ ] **T12.8** — Subir la versión en `VPA/VPADATA.PAS`. Por el calado del
      cambio, corresponde `3.68.0`, no `3.67.7`.
- [ ] **T12.9** — Notas de publicación bilingües en el formato habitual
      (inglés, separador, español), con el apartado de limitaciones conocidas
      bien explícito sobre qué está probado en Wayland y qué no.
- [ ] **T12.10** — Prueba con Alexander en Kubuntu y Astra Linux **antes** de
      publicar, con atención a si SDL3 está disponible en esas versiones.
- [ ] **T12.11** — Crear la rama de versión y la etiqueta según la convención
      del proyecto.

**Criterio de aceptación:** un usuario puede descargar el paquete, ejecutarlo en
una sesión Wayland y jugar, sin compilar nada.

---

## 6. Plan de pruebas de referencia

Comandos que se usan a lo largo de todas las fases.

### 6.1 El ejecutable no depende de ningún backend

```bash
readelf -d build/VPA | grep NEEDED
ldd build/VPA
```

No deben aparecer `libX11`, `libSDL3` ni `libwayland-client`.

### 6.2 El plugin X11 carga y funciona

```bash
ldd build/plugins/libvpagraph-x11.so          # debe mostrar libX11

VPA_GRAPH_BACKEND=x11 \
VPA_GRAPH_PLUGIN_DIR="$PWD/build/plugins" \
./build/VPA 3 ~/PLANETS

lsof -p "$(pidof VPA)" | grep -E 'libvpagraph|libX11|libSDL|libwayland'
```

Debe aparecer `libvpagraph-x11.so` y `libX11.so`; **no** debe aparecer
`libvpagraph-wayland.so`.

### 6.3 Wayland nativo, sin XWayland

```bash
env -u DISPLAY \
  VPA_GRAPH_BACKEND=wayland \
  VPA_GRAPH_PLUGIN_DIR="$PWD/build/plugins" \
  ./build/VPA 3 ~/PLANETS

lsof -p "$(pidof VPA)" | grep -E 'libvpagraph|libwayland|libX11|libSDL'
```

Si funciona sin `DISPLAY`, no está usando X11 ni XWayland. Debe aparecer
`libvpagraph-wayland.so`, `libSDL3.so` y `libwayland-client.so`; **no**
`libvpagraph-x11.so` ni `libX11.so`.

### 6.4 Independencia entre plugins

```bash
mv build/plugins/libvpagraph-wayland.so{,.disabled}
VPA_GRAPH_BACKEND=x11 VPA_GRAPH_PLUGIN_DIR="$PWD/build/plugins" ./build/VPA
mv build/plugins/libvpagraph-wayland.so{.disabled,}

mv build/plugins/libvpagraph-x11.so{,.disabled}
env -u DISPLAY VPA_GRAPH_BACKEND=wayland \
  VPA_GRAPH_PLUGIN_DIR="$PWD/build/plugins" ./build/VPA
mv build/plugins/libvpagraph-x11.so{.disabled,}
```

Ambas ejecuciones deben funcionar.

### 6.5 La selección forzada no degrada en silencio

```bash
VPA_GRAPH_BACKEND=wayland ./build/VPA       # en sesión X11: debe FALLAR
VPA_GRAPH_BACKEND=x11 env -u DISPLAY ./build/VPA   # debe FALLAR
VPA_GRAPH_BACKEND=auto ./build/VPA          # debe elegir el del entorno
```

### 6.6 Regresión visual

```bash
make visual-test            # los dos backends; informe en build/visual/informe.md
VPA_VISUAL_BACKENDS=x11 TESTS/visual/run.sh E17 E21     # un backend, escenas sueltas
```

Necesita la partida de `TESTS/fixture/` y las doradas de `TESTS/golden/`, que
no están en el repositorio (`docs/reference-scenes.md`, 2.1), y el
`RESOURCE.PLN` real (`VPA_RESOURCE`). Umbral: cero píxeles.

### 6.7 Memoria

```bash
make heaptrc
VPA_GRAPH_BACKEND=x11 ./build/VPA 3 ~/PLANETS
```

Con dos RTL en el mismo proceso, esta comprobación pasa de ser conveniente a ser
obligatoria en cada fase.

---

## 7. Riesgos y mitigaciones

| # | Riesgo | Impacto | Mitigación |
|---|--------|---------|------------|
| R1 | Dos RTL de FPC en un proceso con heaps y gestores de hilos separados | Cuelgues y corrupciones intermitentes, dificilísimos de depurar | `T5.9` lo investiga y documenta **antes** de construir encima; regla «quien reserva, libera»; `make heaptrc` en cada fase |
| R2 | *(Confirmado en la Fase 7: Ubuntu 24.04 no trae SDL3 en sus repositorios.)* SDL3 no disponible en distribuciones conservadoras (Astra Linux, Kubuntu 24.04 LTS, Raspberry Pi OS). **Y donde no viene en la distribución, tampoco está en sus repositorios**: la única salida del usuario es compilarla, que para quien solo quiere jugar equivale a no tenerla | Alexander no puede probar Wayland; una parte de los usuarios se queda sin el backend nuevo | Tres capas: (a) el respaldo de fondo —sin SDL3 el `.so` no carga, `auto` se queda en X11 y VPA funciona como hoy—; (b) `T12.3b`, empaquetar `libSDL3.so.0` junto al plugin con `RPATH` `$ORIGIN`, que la licencia zlib de SDL permite; (c) `T12.5b`, documentar las tres vías de obtención. Publicar los plugins por separado |
| R3 | La vía A no converge visualmente | Meses de ajuste fino de trazado y fuentes | La vía B lo elimina de raíz; `T7.4` lo mide antes de comprometerse |
| R4 | PTCPas está poco mantenido y hay que vendorizar más de lo previsto | Deuda de mantenimiento, obligaciones de LGPL | Ya está vendorizado parcialmente y el precedente de `VENDOR/ptcgraph.pp` muestra cómo marcar las modificaciones |
| R5 | El texto del mapa se descuadra por métricas de `.CHR` distintas | Rotura visual masiva y difusa | Vía B lo evita; con vía A, `T8A.8` es la tarea más peligrosa del proyecto |
| R6 | Las 1195 llamadas a `OutTextXY` obligan a tocar código en toda la base | Diff enorme, riesgo de erratas | `T6.1`: el envoltorio conserva nombres y firmas; solo cambia el `uses` |
| R7 | `xfocus` se olvida y el binario sigue enlazando X11 | El objetivo principal no se cumple y se descubre tarde | `T2.10`, `T5.6`, `T6.8` y `T6.12` lo cubren de forma explícita |
| R8 | Regresión silenciosa en X11 durante la migración | Se rompe lo que funcionaba, sin darse cuenta | Imágenes doradas capturadas en la Fase 0, antes de tocar nada |
| R9 | La rama larga diverge de `main` | Conflictos e integración dolorosa | Fusionar al cerrar la Fase 6; mantener `main` liberable |
| R10 | Enlaces Pascal de SDL3 desalineados con la SDL3 instalada | Fallos de enlazado o, peor, corrupción silenciosa de estructuras | `T7.1` fija versión exacta y la vendoriza; comprobar la versión en tiempo de ejecución al inicializar |
| R11 | El plugin Wayland tiene que enmascarar las excepciones de coma flotante (`SetExceptionMask`) o Mesa mata el proceso con *runtime error 207*. La máscara es estado del hilo | Con dos RTL en el proceso (R1), hoy solo cambia en el hilo de la consola, dentro del plugin. Si algún día SDL se llamara desde el hilo de VPA, una división por cero de VPA dejaría de dar error y daría `Inf` | Enmascarar solo en el hilo de `TPTCWrapperThread` (ya es así en el prototipo) y no llamar a SDL desde ningún otro; comprobarlo con una prueba en T8B.9 |
| R12 | `SetMousePos` (lo usa `UNIT/MOUSE.PAS`): Wayland no deja a un cliente mover el puntero salvo con el protocolo `pointer-warp-v1`, reciente, o con trucos de modo relativo | El puntero no salta donde VPA espera en compositores sin ese protocolo. No depende de la vía elegida | Fase 9: probar `SDL_WarpMouseInWindow` en KWin y Mutter reales; si falla, decidir entonces qué hace VPA (no antes, y sin segundo camino de código en el ejecutable). *2026-09-19:* `MoveMouseTo` de la consola SDL3 ya llama a `SDL_WarpMouseInWindow` (`c15c869`). Leído en el código de SDL 3.4: usa `wp_pointer_warp_v1` si el compositor lo anuncia (KWin 6.7.5 de la VM Slackware **sí**, versión 1) y, si no, el truco de `zwp_pointer_constraints_v1` (bloquear, pista de posición, soltar), que tienen casi todos los compositores; sin ninguno de los dos devuelve `False`. *Prueba real (2026-09-19, VM Slackware, KWin 6.7.5, SDL 3.4.16):* el imán **no** mueve el puntero. Revisado: VPA llama al warp sin condiciones (`MouseMove` → `MoveMouseTo` → `VPASetMousePos` → `X11SetMousePos`, el adaptador común → `TSDLConsole.MoveMouseTo`; no hay bandera de capacidad), `Wayland_SeatWarpMouse` es idéntico en SDL 3.4.4 y 3.4.16, y KWin 6.7.5 (`pointer_input.cpp`) acepta el warp si el serial es el del `enter` y el punto cae dentro de la superficie. Hipótesis: el ratón de la VM es una tableta absoluta y el anfitrión deshace (o ni muestra) el warp del invitado. *Traza `WAYLAND_DEBUG=1` de Pablo (misma fecha):* **KWin acepta el warp**: cada `warp_pointer` lleva el serial del `enter` (7973) y, cuando el destino es distinto de donde ya está el puntero, KWin contesta con `wl_pointer.motion` en ese punto exacto ((481,481) y (477,475) con la ventana a ×2); a un warp al mismo punto no contesta, que es lo correcto. Las flechas «que no mueven el puntero» son comportamiento original de VPA, igual en X11 (reproducido): con un objeto fijado, `VPA2.PAS` convierte ←/→ en ^←/^→ (nave o planeta anterior/siguiente, con `CenterMap` y warp a (240,240)) y ↑/↓ en ^↑/^↓ (otro objeto del mismo punto). **Causa confirmada, no es de VPA ni de KWin:** el ratón de la VM es `VirtualBox mouse integration` (`libinput list-devices`), un dispositivo de posición **absoluta**. Segunda traza, moviendo el ratón sobre un objeto fijado en (295,545): llegan `motion` 296→297→298, VPA pide el warp a (295,545), KWin lo aplica y lo confirma con `motion(295,545)`, y el siguiente `motion` real es (300,547): sigue desde la posición del anfitrión e ignora el warp, así que a los `StickyMouseRange` píxeles el imán se suelta. Con un ratón relativo el siguiente `motion` saldría de (295,545). En X11 dentro de la misma VM pasaría lo mismo. **Confirmado por Pablo (2026-09-20):** con la integración del ratón de VirtualBox desactivada (la VM captura el cursor y queda el `ImExPS/2`, relativo) el imán funciona perfectamente en KWin 6.7.5. Cerrado. **Ojo, medido:** SDL emite un `motion` sintético tras *pedir* el warp, lo aplique o no el compositor (el sway 1.9 del contenedor no aplica la pista de `zwp_locked_pointer_v1`): VPA no puede saber si el puntero se movió. Pendiente además Mutter |

---

## 8. Registro de decisiones

Decisiones ya tomadas, para no volver a discutirlas sin motivo nuevo.

| Id | Fecha | Decisión | Motivo |
|----|-------|----------|--------|
| D-01 | 2026-09-12 | Arquitectura de plugins `.so` con ABI versionada, un único ejecutable | Permite arrancar sin el backend contrario; aísla el riesgo del camino X11 |
| D-02 | 2026-09-12 | **No** se reorganiza el árbol a `src/`+`backends/`+`include/`; se añaden `GRAPH/` y `BACKENDS/` al árbol actual | Un traslado rompería `vpa.cfg`, `Makefile`, `.gitattributes` y tres documentos antes de aportar nada |
| D-03 | 2026-09-12 | `GRAPH/vpagraph.pas` conserva **nombres y firmas idénticos** a `ptcgraph` | Convierte la migración de 24 unidades en un cambio de una palabra por unidad en vez de tocar 1195 llamadas |
| D-04 | 2026-09-12 | La ABI cubre **también** ventana, foco, escala, teclado y ratón, no solo dibujo | `UNIT/xfocus.pas` usa Xlib directamente; sin esto el binario seguiría enlazando `libX11` |
| D-05 | 2026-09-12 | Etapas de `Arc`, `PieSlice`, `FillPoly`, `FloodFill`, `DrawPoly`, `Sector`, `Bar3D`, `FillEllipse`, `SetActivePage`, `SetVisualPage` **fuera de la ABI v1** | El inventario demuestra que VPA no las usa |
| D-06 | 2026-09-19 | Motor de dibujo del plugin Wayland: **vía B**, consola PTC sobre SDL3 (`VENDOR/ptc/sdl/`, `-dPTC_SDL3`). Vía A descartada (pendiente desde 2026-09-12) | Medido en la Fase 7: 0 píxeles de diferencia con X11 por construcción, ~540 líneas, `ptcwrapper`/`ptcgraph` intactos; la vía A solo converge transcribiendo `graph.inc`. `docs/adr-001-motor-wayland.md` |
| D-07 | 2026-09-13 | La ABI v1 se define sobre el código que el ejecutable **enlaza**; lo que solo usan `CC/`, `TASKS`, `DETAILS` o las utilidades `VHLP*` queda en `v2` (`TextWidth`, `RegisterBGIDriver`, `GraphErrorMsg`, `Detect`) | `SWITCHES.INC` no define `TASKS`/`VPACC`/`VPAMM` desde hace años; diseñar para código muerto es trabajo de escaparate |
| D-08 | 2026-09-13 | La frontera de ventana de la ABI son **cuatro** peticiones —tamaño de pantalla, pantalla completa, bit «puntero dentro» y modificadores actuales— y una pareja `Suspend`/`Resume` que sustituye a `RestoreCrtMode`+`SetGraphMode(GetGraphMode)` y a la terna de `xfocus` que siempre la sigue. `GrabInputFocus`, `ApplyWindowScale` y los dos `Map*` desaparecen | Con la ventana dentro del plugin no hay nada que buscar por título ni escala que adivinar; el ratón cruza la ABI en coordenadas de superficie 640×480 |
| D-10 | 2026-09-13 | La traducción de teclas a los scancodes del Turbo Pascal y el búfer de teclado viven en el **núcleo**, no en cada plugin; la ABI transporta código de tecla físico + carácter Unicode + modificadores, y los códigos reutilizan los valores de los `PTCKEY_*` de PTCPas | Si cada backend tradujera por su cuenta, X11 y Wayland divergirían en teclas raras y lo notaría antes el usuario que nosotros |
| D-11 | 2026-09-13 | Nada que VPA no use hoy entra en la ABI v1, ni siquiera siendo trivial (`ClearViewPort`, `SetBkColor`, `TextWidth`, `TextHeight`) | La estructura solo crece por el final, así que añadir el día que haga falta no cuesta nada; adelantarlo sí cuesta, porque hay que implementarlo en cada backend |
| D-09 | 2026-09-13 | El evento de teclado de la ABI lleva el **carácter Unicode** además del código de tecla | El arreglo de 3.67.5 para Ctrl-+/- en distribuciones no estadounidenses depende de él; sin carácter se pierde |
| D-12 | 2026-09-15 | El cargador abre los plugins con `dlopen(RTLD_NOW)` vía la unidad `dl`, no con `Dynlibs.LoadLibrary` (`RTLD_LAZY`) | Con enlace perezoso, un plugin al que le falte un símbolo de su biblioteca gráfica carga y cae en mitad de la partida; con `RTLD_NOW` falla en la carga, con mensaje, y `auto` cae a X11. Probado con `bad_unresolved.lpr` |
| D-13 | 2026-09-15 | Todo texto que ve el usuario (detalles del cargador, motivos de la selección, `--help`, `--graph-info`) está en **inglés**; los comentarios del código siguen en español | Toda la consola de VPA está en inglés, y el destinatario de `--graph-info` es Alexander, que no lee español. Mezclar idiomas en un mismo diagnóstico es peor que cualquiera de los dos |
| D-14 | 2026-09-15 | El backend se elige **solo** con `VPA_GRAPH_BACKEND`; no hay opción de línea de comandos | Las opciones `/X` de VPA son de un carácter y `Parameters` es código original; una opción larga nueva abriría un segundo analizador. Si algún día hace falta, se añade en `VPA.PAS` junto a `--graph-info` |
| D-15 | 2026-09-15 | El «controlador de vídeo subyacente» de `--graph-info` no entra en la ABI: cada plugin lo declara en `BackendVersion` (p. ej. `1.0 (ptcgraph/PTCPas)`) y el informe imprime el entorno de sesión completo | No se puede consultar sin `Init`, y `--graph-info` no abre ventana; un campo nuevo en la v1 sería trabajo para todos los backends por un dato informativo |
| D-16 | 2026-09-15 | `VPA_FULLSCREEN` y `VPA_VIDEO` no se documentan en `--help` hasta T10.4 | Hoy nadie las lee (`xfocus.FullscreenRequested` no tiene llamadores); documentarlas sería mentir |
| D-18 | 2026-09-16 | La ventana X del plugin se obtiene de ptc por un método `X11WindowID` añadido a `TX11Console` y expuesto por un `ptcwrapper.pp` vendorizado; no se busca por título | ptcgraph no expone la ventana (`FConsole` y `FX11Display` son privados) y `FindWin` por título era un sondeo de 20×50 ms con respaldo laxo, justo lo que D-08 quería eliminar. Tres líneas de parche, en la línea del que ya existe para DGA |
| D-19 | 2026-09-16 | `BackendVersion` del plugin X11 es `1.0 (ptcgraph, PTCPas 0.99.15, FPC 3.2.2)`, compuesto en tiempo de compilación con `PTCPAS_VERSION` y `{$I %FPCVERSION%}` | Desarrolla D-15. Para el `--graph-info` que lee Alexander, saber con qué PTCPas y qué compilador se hizo el `.so` que le falla vale mucho y no se desactualiza solo |
| D-17 | 2026-09-15 | `--graph-info` se intercepta en `VPA.PAS`, antes de instalar `Terminate`; `--help` en `Parameters`, junto a `/?` | `Terminate` fuerza `ExitCode := 0` en todo `Halt`, y `--graph-info` tiene que salir con 1 cuando no hay backend. La ayuda no necesita código de salida y va con la de siempre |
| D-20 | 2026-09-19 | SDL3 objetivo **3.4.x**, mínima **3.4.4** (la de los enlaces `SDL3-for-Pascal` v0.6 vendorizados); la consola compara `SDL_GetVersion` con `SDL_VERSION` al abrir y se niega con una SDL más vieja | R10. Dentro de la serie 3 la ABI solo crece, así que una SDL más nueva vale y una más vieja no |
| D-21 | 2026-09-19 | El controlador de vídeo se fuerza con `SDL_HINT_VIDEO_DRIVER=wayland` antes de `SDL_Init`, no con la variable de entorno | Medido en T7.2: sin compositor `SDL_Init` falla con mensaje en vez de caer a X11 en silencio, que es lo que exige 6.5 |
| D-22 | 2026-09-19 | El plugin Wayland **no** expone la ventana (`PSDL_Window`) al adaptador: todo lo que toca la ventana (pantalla completa hoy; cursor, puntero y modificadores en la Fase 9) se pide a la consola con `PTCWrapperObject.Option`, que `ptcwrapper` ya ejecuta en el hilo de la consola. `GetScreenSize` devuelve `VPAG_ERR_UNSUPPORTED` | No es simetría con D-18 porque el protocolo no es simétrico: en X11 una segunda conexión puede manipular una ventana por su XID; en Wayland una superficie solo existe en la conexión que la creó, y R11 prohíbe llamar a SDL fuera del hilo de la consola. Un puntero a la ventana en manos del adaptador sería una invitación a violarlo. `ptcwrapper` queda sin tocar. El tamaño de pantalla no se conoce antes de tener ventana; el núcleo ya contempla ese caso y lo demás es de la Fase 10 |
| D-23 | 2026-09-20 | El carácter Unicode del evento de tecla (D-09) sale del **mapa de teclas de SDL** (`SDL_GetKeyFromScancode(scancode, mod, False)`), **no** de `SDL_EVENT_TEXT_INPUT` | `TEXT_INPUT` es un evento aparte que habría que casar con el de tecla y, sobre todo, SDL no lo emite con Ctrl pulsado: justo el caso de Ctrl-+/Ctrl-- que D-09 protege. El mapa de SDL en Wayland se construye del keymap xkb del compositor, con Shift, AltGr y BloqMayús, y es síncrono con la tecla. Es además lo mismo que hace la consola X11, que saca el carácter del keysym y no del texto compuesto, y evita activar la entrada de texto (y el IME) en un juego que no la usa. Corrige lo que pedía T9.2 |
| D-24 | 2026-09-20 | La consola SDL3 **publica** su estado de entrada vivo (modificadores, puntero dentro de la ventana) en una palabra de 32 bits que escribe solo su hilo tras cada `PumpEvents`; el plugin la lee con `ptc.PTCSDLInputState` | Matiza D-22: lo que *toca* la ventana sigue yendo por `Option`, pero una *consulta* por `Option` cuesta una vuelta del bucle de `ptcwrapper` (`Sleep(10)`), y el adaptador pregunta los modificadores en cada evento de ratón y el `Inside` en cada `GetMouseState`. Leer una palabra no llama a SDL (R11) ni necesita cerrojo. `ptcwrapper` sigue sin tocar |
| D-25 | 2026-09-20 | El plugin Wayland **sí** contesta `GetScreenSize` antes de `Init` (corrige la última frase de D-22): `ptc.PTCSDLScreenSize` pregunta a SDL la pantalla **primaria**, en **unidades lógicas**, desde un **hilo auxiliar** que inicia el vídeo de SDL, pregunta y lo cierra; con la consola abierta devuelve el valor que ella publicó al abrir (una palabra de 32 bits, como D-24) | D-22 daba por hecho que un cliente Wayland no sabe el tamaño de la pantalla sin ventana, y no es así: los `wl_output` se anuncian al conectar y SDL los tiene al volver de `SDL_InitSubSystem`. El hilo auxiliar mantiene R11 al pie de la letra (SDL nunca corre en el hilo de VPA ni le toca la máscara de coma flotante) y no deja rastro: SDL define el «hilo de vídeo» como el que inicia el subsistema y lo redefine en cada inicio (`SDL.c`), así que el `Open` posterior en el hilo de la consola empieza limpio. Unidades lógicas porque son las de los tamaños de ventana: con el compositor a ×2, una pantalla de 2560×1440 mide 1280×720 y la escala se recorta al 150 % (lo que pase con la nitidez es de T10.5). La primaria, porque Wayland no deja saber en qué pantalla caerá la ventana. Si no hay compositor devuelve `VPAG_ERR_UNSUPPORTED`, el núcleo no recorta y el error de verdad lo da `Init` |
| D-26 | 2026-09-20 | La ventana SDL se crea con `SDL_WINDOW_HIGH_PIXEL_DENSITY` | Con factor de escala del compositor ≠ 1, sin la bandera SDL dibuja a resolución lógica y amplía el compositor con su filtro (suavizado en KWin): VPA borroso y detalles de 1 px perdidos (medido). Con ella el renderer trabaja en píxeles físicos y la única ampliación es la nuestra, vecino más próximo. Tamaños de ventana, ratón y `GetScreenSize` (D-25) siguen en unidades lógicas, que es la convención de Wayland: `VPA_SCALE=2` ocupa lo mismo en pantalla que cualquier otra aplicación a esa escala |
| D-27 | 2026-09-20 | `VPA_FULLSCREEN` y `VPA_VIDEO` se **retiran**: la única vía de pantalla completa es `VPA_SCALE=fullscreen` (`full`, `max`). Cierra D-16 | Eran un resto del primer intento de pantalla completa: `bc2c09c` (2026-06-23) añadió `VPA_FULLSCREEN` con un enganche en `VPAINIT.PAS` y `fd515ff`, el mismo día, quitó el enganche; `xfocus.FullscreenRequested` siguió compilando sin llamadores hasta que `xfocus` salió del ejecutable en la Fase 6 (`8aecb96`). Hoy no queda código que las lea. Lo único que aportarían es separar «pantalla completa» de «escala» (`VPA_SCALE=2 VPA_FULLSCREEN=1`), y eso es peor o igual: en X11 la consola de ptc no reescala, así que saldría la imagen al 200 % con bandas por los cuatro lados; en Wayland SDL reescala y se vería como `VPA_SCALE=fullscreen` pasando por una escala intermedia que no es la óptima. Decisión de Pablo |
| D-28 | 2026-09-20 | La consola SDL3 fija el color de dibujo del renderer a **negro opaco** nada más crearlo | En SDL 3.4 las bandas del letterbox no se pintan aparte: son lo que deja `SDL_RenderClear`, que borra con el color de dibujo, y un renderer nace con (0,0,0,0) porque su estructura sale de `calloc`. Con un búfer de ventana con alfa el compositor mezcla y por las bandas se ve lo de detrás. sway lo tapaba (respeta la región opaca que SDL declara y, a pantalla completa, pinta negro debajo), KWin no. Las pruebas de la sesión anterior miraban el ratón en las bandas, no sus píxeles; ahora también los píxeles |
| D-29 | 2026-09-20 | La ventana SDL tiene la relación de aspecto **fijada a 4:3** (`SDL_SetWindowAspectRatio`). Decisión de Pablo: la ventana debe verse como en X11, sin bandas | En Wayland el tamaño final lo decide el cliente salvo en maximizada y pantalla completa, y SDL ya aplica la corrección en cada `configure` respetando esa regla (solo encoge; no toca maximizada ni pantalla completa, donde el protocolo exige el tamaño exacto y siguen las bandas negras). Hacerlo a mano con `SDL_SetWindowSize` al recibir `WINDOW_RESIZED` pelearía con el compositor durante un redimensionado interactivo. Efecto en las pruebas: en sway ya no hay bandas en ventana (en mosaico SDL también recorta), así que las pruebas de ratón en las bandas pasan a la sección de pantalla completa y la de píxeles de D-28 se retira (ver T10.2) |

---

## 9. Referencias

- Código actual: `VENDOR/ptcgraph.pp`, `VENDOR/graphh.inc`, `VENDOR/graph.inc`,
  `VENDOR/ptc/core/consolei.inc`, `VENDOR/ptc/x11/`, `UNIT/xfocus.pas`,
  `UNIT/KEYBOARD.PAS`, `UNIT/MOUSE.PAS`.
- PTCPas (OpenPTC portado a Free Pascal), LGPL con excepción de enlazado
  estático: <https://sourceforge.net/projects/ptcpas/>
- Enlaces Pascal de SDL3:
  <https://github.com/PascalGameDevelopment/SDL3-for-Pascal>
- Documentación de SDL3: <https://wiki.libsdl.org/SDL3/>
- Documentos del proyecto: `BUILD.es.md`, `HOWTO.es.md`, `README.es.md`,
  `CHANGE.TXT`.

---

*Documento vivo. Se actualiza en cada sesión de trabajo: se marcan las casillas
completadas con su hash de commit, se anotan los descartes con su motivo y se
añaden las decisiones nuevas a la sección 8.*
