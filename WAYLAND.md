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
| 0 | Preparación y red de seguridad | ◐ en curso |
| 1 | Inventario de la frontera gráfica | ☐ |
| 2 | Definición de la ABI v1 | ☐ |
| 3 | Cargador dinámico | ☐ |
| 4 | Detección y selección de backend | ☐ |
| 5 | Plugin X11 (gráficos, ventana, teclado, ratón) | ☐ |
| 6 | Migración de VPA-Linux a `VPAGraph` | ☐ |
| 7 | Decisión: motor de dibujo del plugin Wayland | ☐ |
| 8 | Motor de dibujo Wayland (vía B o vía A) | ☐ |
| 9 | Eventos: teclado, ratón y cierre de ventana | ☐ |
| 10 | Escalado, HiDPI y pantalla completa | ☐ |
| 11 | Comparación visual automatizada | ☐ |
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
son cotas superiores; la Fase 1 produce el inventario fino):

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

- [ ] **T0.6** — Capturar las escenas de T0.5 con el binario 3.67.6 y guardarlas
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

  Estado (2026-09-13): **hecho salvo la confirmación en la máquina de
  desarrollo**. Se marca cuando `python3 TESTS/compare.py TESTS/golden /tmp/cap`
  dé 20 de 20 allí con las doradas de `SHA256SUMS`.

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
  `SHA256SUMS` y `README.md` en `TESTS/golden/`. Las 14 escenas cuya secuencia
  no cambió son **idénticas píxel a píxel a las capturadas en la máquina de
  desarrollo** (Arch, FPC 3.2.2): con el `RESOURCE.PLN` real el volcado no
  depende de la máquina. Las seis corregidas se han validado mirándolas en el
  contenedor y están pendientes solo de la pasada de confirmación de arriba.
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

**Estado: cumplido** (2026-09-13). Dos pasadas completas en la máquina de
desarrollo (Arch, FPC 3.2.2, `RESOURCE.PLN` real) capturan las 20 escenas y dan
19 de 20 idénticas píxel a píxel; la vigésima es E06, con 30 píxeles de 307 200
en la caja (624,257)-(638,261), que son las dos fases del indicador. El mismo
resultado sale en el contenedor de desarrollo con un `RESOURCE.PLN` ficticio:
misma escena, misma caja, mismos 30 píxeles, con las fases al revés. Es decir,
el parpadeo es reproducible como fenómeno y no como imagen, que es justo lo que
dice la sección 1.3.

Resuelto en T0.6: la E06 que parpadeaba no era la ficha de nave, y con la
secuencia corregida ninguna escena cae en `ArrowBlink`; dos pasadas dan 20 de
20 idénticas. Para el caso futuro, `TESTS/compare.py` admite una caja por
escena en `TESTS/excepciones.txt` (hoy vacío).

---

### Fase 1 — Inventario de la frontera gráfica 🔒

Objetivo: que no quede ni una llamada al mundo exterior sin catalogar. La tabla
de la sección 2.2 es el punto de partida, no el resultado.

- [ ] **T1.1** — `docs/vpagraph-api-inventory.md`, tabla 1: **API Graph**. Para
      cada símbolo: nombre, firma exacta tal y como la declara
      `VENDOR/graphh.inc`, número real de llamadas (excluyendo comentarios),
      ficheros afectados, prioridad (`v1` / `v2` / `no usada`), complejidad y
      equivalencia prevista en el backend nuevo.
- [ ] **T1.2** — Tabla 2: **constantes y tipos** de `ptcgraph` que usa VPA
      (`D8bit`, `m640x480`, `XORPut`, `NormalPut`, `CopyPut`, `HorizDir`,
      `SmallFont`, `DefaultFont`, `SolidLn`, `SolidFill`, `ColorType`,
      `PaletteType`, `ViewPortType`, `grOk`…). Cada una tiene que ser
      reexportada por `VPAGraph` o el `uses` no se podrá sustituir de una pieza.
- [ ] **T1.3** — Tabla 3: **teclado** (`ptccrt`). Documentar el camino completo
      desde la pulsación hasta `Keyboard.ReadKey`, incluyendo `PTCLastKbdFlags`
      y `PTCQuitNoSave`, y el arreglo de 3.67.5 para `Ctrl-+`/`Ctrl--` en
      distribuciones de teclado no estadounidenses (se resolvió comparando el
      **carácter Unicode**, no el scancode: es un requisito, no un detalle).
- [ ] **T1.4** — Tabla 4: **ratón** (`ptcmouse`), incluyendo la emulación por
      software de `StickyMouseRange` en `UNIT/MOUSE.PAS` (`ptcmouse` no expone
      limitación de rango).
- [ ] **T1.5** — Tabla 5: **ventana y foco** (`xfocus`), con las 19 llamadas de
      la sección 2.1 y, para cada una, qué necesita realmente del servidor
      gráfico. Es la tabla que define la mitad menos obvia de la ABI.
- [ ] **T1.6** — Documentar el **contrato de formato de imagen**: diseño exacto
      del buffer de `GetImage`/`PutImage` en `D8bit` (cabecera de 12 bytes con
      tres `longint`, un `word` por píxel), con referencia a los sitios de
      `VPA/TCOMBAT.PAS` y `VPA/EXTFEAT.PAS` que lo construyen a mano.
- [ ] **T1.7** — Documentar el **contrato de paleta**: cómo entra la paleta VGA
      de VPA (valores de 6 bits 0..63 en orden R,B,G en los ficheros originales,
      convertidos a 0..255 RGB para `ptcgraph`, ver `VPA/TCOMBAT.PAS:1438`).
- [ ] **T1.8** — Lista de símbolos **declarados pero no usados** por VPA, con la
      decisión explícita de dejarlos fuera de la ABI v1.
- [ ] **T1.9** — Revisión cruzada: `grep` sobre `VPA/`, `UNIT/`, `CC/`, `VHLP/`
      buscando cualquier identificador de `ptcgraph`, `ptccrt`, `ptcmouse`, `ptc`
      o `xlib` que no aparezca en el inventario.

**Criterio de aceptación:** el inventario cubre el 100 % de los símbolos que
cruzan la frontera; T1.9 no encuentra nada nuevo.

---

### Fase 2 — Definición de la ABI v1 🔒

- [ ] **T2.1** — Crear `GRAPH/vpagraph_abi.inc` con la constante
      `VPAGRAPH_ABI_VERSION = 1` y los tipos de tamaño fijo
      (`TVPAGraphInt8/16/32`, `TVPAGraphUInt8/16/32/64` y sus punteros).
- [ ] **T2.2** — Definir los **códigos de error**. Punto de partida del
      documento original, que es bueno: `0` correcto, `-1` parámetro inválido,
      `-2` ABI incompatible, `-3` tamaño de estructura inválido, `-10` error de
      inicialización, `-20` error de vídeo, `-30` error de memoria, `-100`
      excepción interna capturada. Añadir `-40` «función no soportada por este
      backend».
- [ ] **T2.3** — Definir `TVPAGraphInitParams`: `StructSize`, ancho y alto
      lógicos, escala en porcentaje (sustituye a la variable global
      `ptcgraph.VPAForceScale`), indicador de pantalla completa, título de
      ventana como `PAnsiChar`.
- [ ] **T2.4** — Definir `TVPAGraphInterface`: `StructSize`, `ABIVersion`,
      `BackendName`, `BackendVersion` y los punteros a función. **Orden fijo y
      solo se añade al final**, nunca en medio.
- [ ] **T2.5** — Bloque de funciones de **ciclo de vida**: `Init`, `Shutdown`,
      `GetLastError(Buffer, BufferSize)`, `Present`, `GraphResult`.
- [ ] **T2.6** — Bloque de **dibujo** (el subconjunto real de la Fase 1, no la
      API Graph completa): `ClearDevice`, `ClearViewPort`, `SetViewPort`,
      `GetViewSettings`, `SetColor`, `GetColor`, `SetBkColor`, `SetLineStyle`,
      `SetFillStyle`, `SetWriteMode`, `PutPixel`, `GetPixel`, `Line`, `LineTo`,
      `LineRel`, `MoveTo`, `Rectangle`, `Bar`, `Circle`, `Ellipse`.
- [ ] **T2.7** — Bloque de **imágenes**: `ImageSize`, `GetImage`, `PutImage`,
      con el contrato de memoria de T1.6 documentado **dentro del `.inc`**, en
      comentario, no solo en el inventario.
- [ ] **T2.8** — Bloque de **paleta**: `SetRGBPalette`, `GetRGBPalette` y lo que
      T1.7 determine. Las tablas se pasan por puntero más número de entradas,
      nunca como array Pascal.
- [ ] **T2.9** — Bloque de **texto**: `OutTextXY(X, Y, PAnsiChar)`,
      `SetTextStyle`, `SetTextJustify`, `TextWidth`, `TextHeight`,
      `InstallUserFont(PAnsiChar)`. Decisión a dejar escrita: la conversión
      shortstring → `PAnsiChar` ocurre **solo** en `GRAPH/vpagraph.pas`.
- [ ] **T2.10** — Bloque de **ventana, foco y escala** (la aportación que no
      estaba en el plan original): `ResolveScale`, `ApplyWindowScale`,
      `GrabInputFocus`, `ReleaseInputFocus`, `RequestFullscreen`,
      `ReleaseFullscreen`, `WantFullscreen`, `PointerInsideWindow`,
      `MapMouseToSurface`, `MapSurfaceToWindow`, `BackendReady`.
- [ ] **T2.11** — Bloque de **teclado y ratón**: `KeyPressed`, `ReadKey`,
      `GetKbdFlags`, `GetQuitNoSave`, `ShowMouse`, `HideMouse`,
      `GetMouseState`, `SetMousePos`, y `PollEvent(EventOut)` con la
      convención `0` sin evento / `1` evento / negativo error.
- [ ] **T2.12** — Definir `TVPAGraphEvent` (`StructSize`, `EventType`,
      `Timestamp`, `KeyCode`, `ScanCode`, `UnicodeChar`, `Modifiers`, `MouseX`,
      `MouseY`, `MouseButton`, `Width`, `Height`). **`UnicodeChar` es
      obligatorio**: sin él no se puede replicar el arreglo de `Ctrl-+`/`Ctrl--`
      de 3.67.5.
- [ ] **T2.13** — Definir el prototipo del punto de entrada único
      `VPAGraph_GetInterface(RequestedABIVersion, InterfaceSize, InterfaceOut)`.
- [ ] **T2.14** — Escribir `docs/abi-compatibility.md`: qué se puede cambiar sin
      subir la versión de ABI (nada que altere el diseño existente), qué obliga
      a subirla y cómo se comporta un plugin viejo ante un ejecutable nuevo y
      viceversa.
- [ ] **T2.15** — Escribir `TESTS/abi/stub_backend.lpr`: un plugin de juguete
      que no dibuja nada pero devuelve una interfaz válida. Es el banco de
      pruebas del cargador de la Fase 3.
- [ ] **T2.16** — Escribir también los plugins **defectuosos** de prueba: uno
      sin el símbolo de entrada, uno con `ABIVersion` = 99, uno con
      `StructSize` incorrecto y uno que devuelve punteros nulos en funciones
      obligatorias.

**Criterio de aceptación:** `vpagraph_abi.inc` compila tanto desde una unidad en
`-Mtp` como desde una en `{$mode objfpc}`, y `stub_backend.so` se construye.

---

### Fase 3 — Cargador dinámico 🔒

- [ ] **T3.1** — `GRAPH/vpagraph_loader.pas`. **Única unidad de todo el
      proyecto que puede usar `Dynlibs`.** Anotarlo en su cabecera.
- [ ] **T3.2** — Resolución de la ruta del plugin, en este orden:
      1. `$VPA_GRAPH_PLUGIN_DIR` si está definida;
      2. `<directorio del ejecutable>/plugins/` (para ejecutar sin instalar);
      3. el directorio de instalación (`/usr/lib/vpa-linux/`, ajustable en
         tiempo de compilación).
      Siempre rutas absolutas; **nunca el directorio de trabajo actual**.
- [ ] **T3.3** — Validaciones de seguridad antes de `LoadLibrary`: el fichero
      existe, es un fichero regular (no enlace a dispositivo ni directorio), y
      es legible.
- [ ] **T3.4** — Carga, resolución de `VPAGraph_GetInterface` y llamada con la
      versión y el tamaño de estructura que espera el ejecutable.
- [ ] **T3.5** — Validación de la tabla devuelta: `StructSize` coherente,
      `ABIVersion` compatible, `BackendName`/`BackendVersion` no nulos, y
      **todos** los punteros obligatorios asignados. Un plugin a medio rellenar
      se rechaza entero: no se acepta «funciona a medias».
- [ ] **T3.6** — Descarga ordenada: anular la tabla de funciones *antes* de
      `UnloadLibrary`, para que un fallo posterior dé un puntero nulo detectable
      y no un salto a memoria liberada.
- [ ] **T3.7** — Registro de diagnóstico: qué plugin se intentó, desde qué ruta,
      con qué resultado. Silencioso por defecto, detallado con
      `VPA_GRAPH_DEBUG=1`.
- [ ] **T3.8** — `GRAPH/vpagraph_errors.pas`: traducción de códigos numéricos a
      texto en español y en inglés, y recogida del mensaje del plugin vía
      `GetLastError` con buffer del llamante.
- [ ] **T3.9** — `TESTS/abi/loader_test.lpr`: carga el stub, lo descarga, lo
      vuelve a cargar 100 veces y comprueba que no hay fugas (`-gh`).
- [ ] **T3.10** — Probar el cargador contra los cuatro plugins defectuosos de
      T2.16: los cuatro deben ser rechazados con un mensaje distinto y útil.

**Criterio de aceptación:** el ejecutable de prueba carga el stub, rechaza los
cuatro plugins malos con mensajes diferenciados, y 100 ciclos de carga/descarga
no dejan memoria ni descriptores colgando.

---

### Fase 4 — Detección y selección de backend 🔒

- [ ] **T4.1** — `GRAPH/vpagraph_detect.pas`, con soporte de
      `VPA_GRAPH_BACKEND` con valores `auto` (por defecto), `x11` y `wayland`.
- [ ] **T4.2** — Algoritmo de detección automática:
      1. si `WAYLAND_DISPLAY` está definida → intentar Wayland;
      2. si no, o si falla, y `DISPLAY` está definida → intentar X11;
      3. si `XDG_SESSION_TYPE` está definida, usarla como desempate;
      4. si fallan todos, error con **la lista acumulada de motivos**, no un
         genérico «no se pudo iniciar el modo gráfico».
- [ ] **T4.3** — **Regla de no-degradación silenciosa.** Con
      `VPA_GRAPH_BACKEND=wayland`, si el plugin Wayland falla, `VPA` termina con
      error. No cae a X11. Igual en sentido contrario. El respaldo solo existe
      en modo `auto`.
- [ ] **T4.4** — Implementar `--graph-info`: imprime backend solicitado, backend
      elegido, ruta del plugin, versión de ABI, versión del backend y
      controlador de vídeo subyacente, y sale sin abrir ventana. Herramienta de
      diagnóstico número uno para los informes de Alexander.
- [ ] **T4.5** — Ampliar `--help` para documentar las variables de entorno
      nuevas junto a las existentes (`VPA_SCALE`, `VPA_FULLSCREEN`, `VPA_VIDEO`).
- [ ] **T4.6** — Pruebas: los seis casos de la matriz
      (`auto`/`x11`/`wayland`) × (sesión X11 / sesión Wayland).

**Criterio de aceptación:** la selección forzada nunca cambia de backend en
silencio; `--graph-info` da una salida correcta en ambos entornos.

---

### Fase 5 — Plugin X11: gráficos, ventana, teclado y ratón 🔒

La fase más delicada de todas, porque no aporta ninguna funcionalidad nueva y
puede romper lo que ya funciona. La meta es **comportamiento idéntico, bit a
bit**, con `ptcgraph` accedido a través del `.so`.

- [ ] **T5.1** — Crear `plugins.cfg` para compilar los `.so`: `{$mode objfpc}`,
      código independiente de posición, salida a `build/plugins/`, rutas de
      unidades a `VENDOR/` y `build/ptcunits/`. **No** hereda `-Mtp` ni las
      comprobaciones desactivadas de `vpa.cfg`: durante el desarrollo los
      plugins se compilan con las comprobaciones **activadas**.
- [ ] **T5.2** — Añadir al `Makefile` los objetivos `plugins`, `x11-plugin` y
      (más adelante) `wayland-plugin`, respetando `.NOTPARALLEL` y la
      dependencia con el objetivo `ptc` existente.
- [ ] **T5.3** — `BACKENDS/X11/vpagraph_x11.lpr`: biblioteca que exporta
      únicamente `VPAGraph_GetInterface`.
- [ ] **T5.4** — `BACKENDS/X11/vpagraph_x11_impl.pas`: adaptadores `cdecl` que
      envuelven `ptcgraph`. Cada uno con su `try..except` propio, porque
      **ninguna excepción puede cruzar** (regla 3.4). Traducción de shortstring:
      el adaptador recibe `PAnsiChar` y llama a `ptcgraph` con `string`.
- [ ] **T5.5** — Adaptar el ciclo de vida: `Init` traduce
      `TVPAGraphInitParams` a `VPAForceScale` + `InitGraph(D8bit, m640x480, '')`;
      `Shutdown` llama a `CloseGraph`. Conservar la protección de 3.67.5 contra
      `SetGraphMode` destruyendo la ventana.
- [ ] **T5.6** — **Trasladar `UNIT/xfocus.pas` al plugin.** Todo el código Xlib
      pasa a `BACKENDS/X11/`; en el ejecutable no queda ni un `uses xlib`. La
      conexión X persistente y el cursor en blanco viven ahora dentro del `.so`,
      que es exactamente donde deben estar.
- [ ] **T5.7** — Implementar el bloque de ventana/foco/escala de la ABI (T2.10)
      sobre ese código trasladado, **conservando la semántica de `VPA_SCALE`
      completa**, incluida la interpretación heredada de 1..20 como
      multiplicador.
- [ ] **T5.8** — Implementar el bloque de teclado y ratón (T2.11) sobre
      `ptccrt` y `ptcmouse`, incluidos `PTCLastKbdFlags`, `PTCQuitNoSave` y la
      emulación por software del rango del ratón.
- [ ] **T5.9** — **Resolver la cuestión de los hilos.** `ptcgraph` levanta un
      hilo para el bucle de eventos X11 y por eso `cthreads` va el primero en
      `VPA/VPA.PAS`. Al mudarse `ptcgraph` al `.so`, hay que determinar
      experimentalmente: (a) si el `.so` necesita su propio `cthreads`;
      (b) si el ejecutable puede prescindir de él; (c) cómo se comporta el
      gestor de hilos con dos RTL en el mismo proceso. **Documentar el
      resultado en `docs/threads-and-rtl.md` antes de seguir**: si esto se
      entiende mal, aparecerán cuelgues intermitentes imposibles de depurar.
- [ ] **T5.10** — Verificar aislamiento de dependencias:
      `ldd build/plugins/libvpagraph-x11.so` muestra `libX11`;
      `readelf -d build/VPA` no.
- [ ] **T5.11** — Arnés de prueba `TESTS/x11/scene_test.lpr`: dibuja las escenas
      geométricas básicas a través del plugin y vuelca el framebuffer. Comparar
      con el mismo programa llamando directamente a `ptcgraph`. **Debe dar cero
      píxeles de diferencia.**

**Criterio de aceptación:** `scene_test` a través del plugin es idéntico a
`scene_test` directo; el `.so` enlaza X11 y el arnés que lo carga, no.

---

### Fase 6 — Migración de VPA-Linux a `VPAGraph` 🔒

Aquí está el truco que hace viable toda la operación.

> **Decisión de diseño:** `GRAPH/vpagraph.pas` expone procedimientos con los
> **mismos nombres y las mismas firmas** que `ptcgraph` (mismos tipos:
> `smallint`, `ColorType`, shortstring), y reexporta sus constantes y tipos. Así
> la migración de las 24 unidades es **cambiar una palabra en la cláusula
> `uses`**, no reescribir 1195 llamadas a `OutTextXY` ni 706 a `SetColor`. El
> diff de esta fase debe ser de unas 30 líneas en total, más la unidad nueva.

- [ ] **T6.1** — Escribir `GRAPH/vpagraph.pas` con la API pública completa:
      firmas idénticas a `ptcgraph`, reexportación de constantes y tipos (T1.2),
      conversión de cadenas, y redirección a la tabla de funciones del backend.
- [ ] **T6.2** — Comprobar que `VPAGraph` es consumible desde `-Mtp`
      compilando una unidad de prueba mínima antes de tocar nada real.
- [ ] **T6.3** — Inicialización: `InitGraph` de `VPAGraph` detecta, carga y
      valida el backend antes de delegar. `CloseGraph` descarga el plugin.
- [ ] **T6.4** — Añadir `-FuGRAPH` y `-FiGRAPH` a `vpa.cfg`.
- [ ] **T6.5** — Sustituir `ptcgraph` por `VPAGraph` en las 24 unidades, **una
      por commit o en grupos pequeños y coherentes**, verificando compilación
      tras cada grupo:

  - [ ] `VPA/VPADATA.PAS`
  - [ ] `VPA/SCREEN.PAS`
  - [ ] `VPA/VPAINIT.PAS`
  - [ ] `VPA/VPAEXIT.PAS`
  - [ ] `VPA/VPA2.PAS`
  - [ ] `VPA/VPA3.PAS`
  - [ ] `VPA/VPA4.PAS`
  - [ ] `VPA/INI.PAS`
  - [ ] `VPA/CONFIG.PAS`
  - [ ] `VPA/MESSAGES.PAS`
  - [ ] `VPA/EXTFEAT.PAS`
  - [ ] `VPA/TCOMBAT.PAS`
  - [ ] `VPA/BUILDING.PAS`
  - [ ] `VPA/TASKS.PAS`
  - [ ] `VPA/PLANSIM.PAS`
  - [ ] `VPA/REPORT.PAS`
  - [ ] `VPA/SCORES.PAS`
  - [ ] `VPA/SCRSAVER.PAS`
  - [ ] `VPA/DETAILS.PAS`
  - [ ] `VPA/VCS.PAS`
  - [ ] `UNIT/VHLP.PAS`
  - [ ] `UNIT/VHLPSHOW.PAS`
  - [ ] `VHLP/VHLP.PAS` *(duplicado histórico de `UNIT/`; comprobar cuál gana
        según el orden de `-Fu` en `vpa.cfg` y decidir si procede unificarlos —
        tarea aparte, no mezclar con esta)*
  - [ ] `VHLP/VHLPSHOW.PAS` *(ídem)*

- [ ] **T6.6** — Reescribir `UNIT/KEYBOARD.PAS` contra la ABI en lugar de
      `ptccrt` + `xfocus`.
- [ ] **T6.7** — Reescribir `UNIT/MOUSE.PAS` contra la ABI en lugar de
      `ptcmouse` + `xfocus`.
- [ ] **T6.8** — Sustituir las 19 llamadas a `xfocus` (sección 2.1) por llamadas
      a `VPAGraph`, y **eliminar `UNIT/xfocus.pas`** del ejecutable.
- [ ] **T6.9** — Revisar el `uses` de `VPA/VPA.PAS` a la luz de T5.9.
- [ ] **T6.10** — `VHLP/VHLPMAKE.PAS` también enlaza la unidad gráfica (por eso
      el `Makefile` lo ejecuta con `xvfb-run`): decidir si pasa por `VPAGraph` o
      si se queda con `ptcgraph` como herramienta interna de compilación. La
      segunda opción es más simple y no compromete el objetivo, porque no forma
      parte del binario distribuido.
- [ ] **T6.11** — Verificación final: `grep -rn "ptcgraph\|ptccrt\|ptcmouse\|xlib"
      VPA/ UNIT/ CC/` no devuelve nada fuera de comentarios históricos.
- [ ] **T6.12** — `readelf -d build/VPA | grep NEEDED` comparado con la línea
      base de T0.3: `libX11` y compañía han desaparecido.
- [ ] **T6.13** — **Regresión completa**: reproducir las escenas de T0.5 y
      compararlas con las imágenes doradas de T0.6. Cero diferencias.
- [ ] **T6.14** — Partida real completa en X11: cargar una partida de
      `EXAMPLES/`, jugar un turno, guardar, salir y volver a entrar.

**Criterio de aceptación:** VPA funciona en X11 exactamente igual que 3.67.6, el
binario no enlaza X11, y las imágenes doradas coinciden píxel a píxel.

> En este punto la arquitectura está completa y **no se ha escrito ni una línea
> de Wayland**. Buen momento para fusionar a `main` y, si se quiere, publicar
> una versión intermedia: aporta la arquitectura de plugins sin riesgo añadido.

---

### Fase 7 — Decisión: motor de dibujo del plugin Wayland 🔒

Prototipos acotados en tiempo, para decidir con datos en vez de con intuición.
**Este código es desechable y no se integra.**

- [ ] **T7.1** — Fijar la versión de SDL3 objetivo y vendorizar los enlaces
      Pascal de `PascalGameDevelopment/SDL3-for-Pascal` en `VENDOR/sdl3/`
      (licencia MPL-2.0 / zlib, compatible con la del port). Anotar versión
      exacta y fecha.
- [ ] **T7.2** — Prototipo mínimo de SDL3 en Free Pascal: abrir ventana en
      Wayland, subir una textura de 640×480 y presentarla. Sin ABI, sin plugin,
      sin nada. Solo confirmar que la cadena FPC → enlaces → SDL3 → Wayland
      funciona en la máquina de desarrollo.
- [ ] **T7.3** — **Prototipo de la vía B**: esqueleto de una consola PTC sobre
      SDL3 en `VENDOR/ptc/sdl/`. No tiene que funcionar; tiene que responder a
      tres preguntas: ¿cuántos métodos de `IPTCConsole` hay que implementar de
      verdad?, ¿hace falta tocar `ptcwrapper` (que **no** está vendorizado, viene
      de `fp-units-gfx`)?, ¿cómo encaja en `TPTCConsoleFactory`?
- [ ] **T7.4** — **Prototipo de la vía A**: implementar sobre SDL3 solo
      `Line` con `SetLineStyle` y `SetWriteMode(XORPut)`, y comparar píxel a
      píxel con `ptcgraph` usando `TESTS/compare.py`. Es la prueba de fuego: si
      reproducir *una* primitiva ya cuesta ajustes de trazado, reproducir las
      veinte y las fuentes `.CHR` es un proyecto en sí mismo.
- [ ] **T7.5** — Escribir `docs/adr-001-motor-wayland.md`: opciones, medidas
      obtenidas en T7.3 y T7.4, decisión y motivos. Registrarlo también en la
      sección 8 de este documento.
- [ ] **T7.6** — Marcar en la Fase 8 la vía descartada como `- [-]`, con el
      motivo. No se borra.

**Criterio de aceptación:** decisión tomada, escrita y justificada con
mediciones, no con preferencias.

---

### Fase 8 — Motor de dibujo Wayland 🔒

Se ejecuta **una** de las dos vías. La otra queda documentada como descartada.

#### Vía B — Consola PTC sobre SDL3 *(recomendada)*

- [ ] **T8B.1** — Vendorizar las piezas de PTCPas que falten (`ptcwrapper` y lo
      que T7.3 haya identificado), con el aviso de modificación que exige la
      LGPL, igual que ya se hizo en `VENDOR/ptcgraph.pp`.
- [ ] **T8B.2** — `VENDOR/ptc/sdl/sdlconsoled.inc` y `sdlconsolei.inc`:
      declaración e implementación de la consola SDL3.
- [ ] **T8B.3** — Apertura de ventana: `SDL_Init(VIDEO)` con el controlador de
      vídeo forzado a `wayland` (hint de SDL3, no solo la variable de entorno),
      ventana redimensionable, textura de presentación en streaming.
- [ ] **T8B.4** — Superficie lógica indexada de 8 bits y ciclo
      `Lock` / `Unlock` / `Update`, conservando la semántica de PTC.
- [ ] **T8B.5** — Conversión indexado → 32 bits en la presentación, respetando
      la ruta de paleta existente.
- [ ] **T8B.6** — Presentación con **filtrado de vecino más próximo**: la
      ventana actual escala con bordes nítidos y el aspecto tiene que ser el
      mismo. Nada de suavizado.
- [ ] **T8B.7** — Cola de eventos: traducir eventos SDL3 a eventos PTC
      (`IPTCKeyEvent`, `IPTCMouseEvent`, `IPTCCloseEvent`), que es lo que hace
      que `ptccrt` y `ptcmouse` funcionen sin tocarlos.
- [ ] **T8B.8** — Registrar la consola en `TPTCConsoleFactory` mediante un
      define de compilación, de modo que la misma base de PTC produzca la
      consola X11 o la SDL según cómo se compile el plugin.
- [ ] **T8B.9** — Construir `libvpagraph-wayland.so` reutilizando el adaptador
      de ABI de la Fase 5 (idealmente **el mismo fichero**, compilado dos veces
      con distinto define: si el adaptador es común, la equivalencia entre
      backends deja de ser una esperanza y pasa a ser una propiedad del código).
- [ ] **T8B.10** — Comparación píxel a píxel contra las imágenes doradas.
      Objetivo realista aquí: **cero diferencias**.

#### Vía A — Reimplementación BGI sobre SDL3 *(plan de contingencia)*

- [ ] **T8A.1** — Framebuffer indexado de 8 bits, paleta y presentación SDL3.
- [ ] **T8A.2** — Estado gráfico: color, color de fondo, estilo de línea,
      estilo de relleno, modo de escritura, viewport, posición actual.
- [ ] **T8A.3** — Primitivas: `PutPixel`, `GetPixel`, `Line` (con estilo y
      grosor), `LineTo`, `LineRel`, `MoveTo`, `Rectangle`, `Bar`, `Circle`,
      `Ellipse`. Solo las del inventario real.
- [ ] **T8A.4** — Recorte y viewport con la semántica exacta de BGI.
- [ ] **T8A.5** — Modos de escritura, empezando por `XORPut` (36 usos).
- [ ] **T8A.6** — Paleta: `SetRGBPalette`, `GetRGBPalette` y la conversión de
      T1.7.
- [ ] **T8A.7** — Imágenes: `ImageSize`, `GetImage`, `PutImage` con el formato
      exacto de T1.6, incluidos los buffers construidos a mano por `TCOMBAT` y
      `EXTFEAT`.
- [ ] **T8A.8** — Texto: fuente bitmap 8×8 (`DefaultFont`), cargador y
      rasterizador de `.CHR` (`LittFont`), justificación, `TextWidth`,
      `TextHeight`. La parte más ingrata y la que más se nota si falla.
- [ ] **T8A.9** — Comparación píxel a píxel e iteración hasta converger.
      Documentar y justificar cada diferencia que se decida tolerar.

**Criterio de aceptación:** `env -u DISPLAY VPA_GRAPH_BACKEND=wayland` abre
ventana y dibuja las escenas de referencia con el resultado acordado en la vía
elegida.

---

### Fase 9 — Eventos: teclado, ratón y cierre de ventana 🔒

Con la vía B esta fase es pequeña (la consola ya entrega eventos y `ptccrt` /
`ptcmouse` los consumen). Con la vía A hay que hacerla entera.

- [ ] **T9.1** — Tabla de traducción de teclas SDL3 → códigos que espera
      `UNIT/KEYBOARD.PAS`: teclas extendidas, función, cursores, `Ctrl`+letra,
      `Alt`+letra.
- [ ] **T9.2** — **Entrada de texto para distribuciones no estadounidenses.**
      `Ctrl-+` y `Ctrl--` se arreglaron en 3.67.5 comparando el carácter
      Unicode, no el scancode. En SDL3 hay que combinar el evento de tecla con
      el de entrada de texto y rellenar `UnicodeChar` en `TVPAGraphEvent`.
      Probar explícitamente con distribución española y con la rusa, que es la
      de Alexander.
- [ ] **T9.3** — Modificadores (`Shift`/`Ctrl`/`Alt`) en el formato heredado
      estilo BIOS `0040:0017` que devuelve hoy `xfocus.KbdModifiers`.
- [ ] **T9.4** — Ratón: posición, botones, movimiento, y la emulación de
      `StickyMouseRange`.
- [ ] **T9.5** — Ocultar el cursor del sistema dentro de la ventana, como hace
      hoy `xfocus` con un cursor en blanco.
- [ ] **T9.6** — Cierre de ventana: mapearlo al camino existente
      (`PTCQuitNoSave` / emulación de `Ctrl-C`) para que el guardado de
      emergencia de `VPA/VPAEXIT.PAS` siga funcionando. **Probar con una partida
      con cambios sin guardar**: es justamente el caso en que un fallo aquí
      duele de verdad.
- [ ] **T9.7** — Foco de teclado al abrir y al volver del editor externo
      (`$VISUAL`/`$EDITOR`, arreglado en 3.67.5).
- [ ] **T9.8** — Repetición de teclas y latencia comparadas con X11.

**Criterio de aceptación:** se puede jugar un turno completo en Wayland solo con
teclado y ratón, sin diferencias perceptibles respecto a X11.

---

### Fase 10 — Escalado, HiDPI y pantalla completa 🔒

- [ ] **T10.1** — Implementar `ResolveScale` para Wayland respetando la
      semántica completa de `VPA_SCALE` (sección 2.3.10), obteniendo el tamaño
      de pantalla de SDL3 en lugar de Xlib.
- [ ] **T10.2** — Presentación lógica de 640×480 con relación de aspecto
      preservada y bandas laterales cuando haga falta.
- [ ] **T10.3** — Transformación de coordenadas del ratón de ventana física a
      superficie lógica (equivalentes de `MapMouseToSurface` y
      `MapSurfaceToWindow`), delegando en la conversión que ofrece SDL3 en lugar
      de repetir la aritmética a mano.
- [ ] **T10.4** — Pantalla completa: `VPA_FULLSCREEN`, `VPA_VIDEO=fullscreen` y
      `VPA_SCALE=fullscreen`, con las tres rutas que hoy llaman a
      `RequestFullscreen`/`ReleaseFullscreen`.
- [ ] **T10.5** — HiDPI: comprobar el comportamiento con factor de escala del
      compositor ≠ 1. Es el caso en el que Wayland difiere más de X11 y donde es
      más probable que el ratón se descuadre.
- [ ] **T10.6** — Redimensionado de ventana en caliente sin perder el contenido.
- [ ] **T10.7** — Probar en 2560×1440 (máquina de desarrollo) y en resoluciones
      pequeñas donde el escalado tenga que recortarse.

**Criterio de aceptación:** sin distorsión, ratón exacto en todas las escalas,
y comportamiento estable con HiDPI.

---

### Fase 11 — Comparación visual automatizada ⚡

- [ ] **T11.1** — `TESTS/visual/run.sh`: ejecuta el catálogo de escenas de T0.5
      en los dos backends y vuelca los framebuffers.
- [ ] **T11.2** — Comparar contra las imágenes doradas y generar un informe
      (píxeles distintos, mapa de diferencias, veredicto).
- [ ] **T11.3** — Fijar el umbral de tolerancia. Con la vía B debería ser
      **cero**. Con la vía A, definir y **justificar por escrito** cada
      diferencia tolerada.
- [ ] **T11.4** — Añadir escenas específicas para lo que sabemos que es frágil:
      `XORPut` de las gomas elásticas, texto con `LittFont` en el mapa,
      `GetImage`/`PutImage` del visor de combate, viewport del panel derecho
      (el del desplazamiento de 32 píxeles de 3.67.5), paleta del gráfico de
      estadísticas (el del azul ilegible de 3.67.5).
- [ ] **T11.5** — Documentar cómo regenerar las imágenes doradas cuando un
      cambio *deliberado* las invalide, y la norma de que regenerarlas siempre
      es una decisión consciente que se anota, nunca un paso automático para
      que las pruebas dejen de quejarse.

**Criterio de aceptación:** las pruebas visuales pasan en los dos backends y el
informe es reproducible.

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
VPA_GRAPH_DUMP=/tmp/cur xvfb-run -a ./build/VPA 3 EXAMPLES/...
python3 TESTS/compare.py TESTS/golden /tmp/cur
```

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
| R2 | SDL3 no disponible en distribuciones conservadoras (Astra Linux, Kubuntu 24.04 LTS, Raspberry Pi OS). **Y donde no viene en la distribución, tampoco está en sus repositorios**: la única salida del usuario es compilarla, que para quien solo quiere jugar equivale a no tenerla | Alexander no puede probar Wayland; una parte de los usuarios se queda sin el backend nuevo | Tres capas: (a) el respaldo de fondo —sin SDL3 el `.so` no carga, `auto` se queda en X11 y VPA funciona como hoy—; (b) `T12.3b`, empaquetar `libSDL3.so.0` junto al plugin con `RPATH` `$ORIGIN`, que la licencia zlib de SDL permite; (c) `T12.5b`, documentar las tres vías de obtención. Publicar los plugins por separado |
| R3 | La vía A no converge visualmente | Meses de ajuste fino de trazado y fuentes | La vía B lo elimina de raíz; `T7.4` lo mide antes de comprometerse |
| R4 | PTCPas está poco mantenido y hay que vendorizar más de lo previsto | Deuda de mantenimiento, obligaciones de LGPL | Ya está vendorizado parcialmente y el precedente de `VENDOR/ptcgraph.pp` muestra cómo marcar las modificaciones |
| R5 | El texto del mapa se descuadra por métricas de `.CHR` distintas | Rotura visual masiva y difusa | Vía B lo evita; con vía A, `T8A.8` es la tarea más peligrosa del proyecto |
| R6 | Las 1195 llamadas a `OutTextXY` obligan a tocar código en toda la base | Diff enorme, riesgo de erratas | `T6.1`: el envoltorio conserva nombres y firmas; solo cambia el `uses` |
| R7 | `xfocus` se olvida y el binario sigue enlazando X11 | El objetivo principal no se cumple y se descubre tarde | `T2.10`, `T5.6`, `T6.8` y `T6.12` lo cubren de forma explícita |
| R8 | Regresión silenciosa en X11 durante la migración | Se rompe lo que funcionaba, sin darse cuenta | Imágenes doradas capturadas en la Fase 0, antes de tocar nada |
| R9 | La rama larga diverge de `main` | Conflictos e integración dolorosa | Fusionar al cerrar la Fase 6; mantener `main` liberable |
| R10 | Enlaces Pascal de SDL3 desalineados con la SDL3 instalada | Fallos de enlazado o, peor, corrupción silenciosa de estructuras | `T7.1` fija versión exacta y la vendoriza; comprobar la versión en tiempo de ejecución al inicializar |

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
| D-06 | 2026-09-12 | Motor de dibujo del plugin Wayland: **pendiente** (Fase 7), con recomendación de la vía B (consola PTC sobre SDL3) | Se decide con prototipos medidos, no por intuición |

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
