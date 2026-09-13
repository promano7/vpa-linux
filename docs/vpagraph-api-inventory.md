# Inventario de la frontera gráfica de VPA-Linux

Resultado de la **Fase 1** de `WAYLAND.md`: catálogo de cada símbolo por el que
el ejecutable `VPA` toca el sistema de ventanas, con su firma real, cuántas veces
se usa, desde dónde y qué tiene que ofrecer un backend nuevo para sustituirlo.
Este documento es el contrato de partida de la ABI v1 (Fase 2); la tabla
preliminar de `WAYLAND.md` §2.2 queda superada por las de aquí.

Cifras tomadas de la rama `feature/wayland` tras cerrar la Fase 0.

## 0. Método

Las cuentas las produce `TESTS/inventory.py` (solo biblioteca estándar, como
`compare.py`). Para cada símbolo que exporta la sección `interface` de
`VENDOR/ptcgraph.pp` (con `VENDOR/graphh.inc`), `VENDOR/ptccrt.pp`,
`VENDOR/ptcmouse.pp` y `UNIT/xfocus.pas`, cuenta sus apariciones en `VPA/`,
`UNIT/`, `CC/` y `VHLP/` **fuera de comentarios y de literales de cadena**, solo
en ficheros que tienen la unidad en su `uses` (o la referencia calificada,
`xfocus.ResolveScale`). Tres decisiones de método que cambian las cifras
respecto a §2.2:

1. **Enlazado frente a no enlazado.** `VPA/SWITCHES.INC` no define `TASKS`,
   `VPACC` ni `VPAMM`, así que el ejecutable **no enlaza** `CC/*`,
   `VPA/TASKS.PAS` ni `VPA/DETAILS.PAS` (este último está comentado en el
   `uses` de `VPA.PAS`). `VHLPSHOW` y `VHLPMAKE` son utilidades independientes.
   El guion calcula el cierre transitivo de `uses` desde `VPA/VPA.PAS` y marca
   con `*` los ficheros fuera de él. **La ABI v1 se define sobre lo enlazado**;
   lo demás se inventaría para que no sorprenda si algún día se activa.
2. **Copias de `VHLP/`.** `vpa.cfg` pone `-FuUNIT` antes de `-FuVHLP`, así que
   el compilador toma siempre `UNIT/VHLP.PAS`; `VHLP/VHLP.PAS` es una copia
   antigua (`keys` como `int` en vez de `word`) que no se compila y no se cuenta.
3. **Sombras de nombre.** Un identificador igual al de `ptcgraph` no siempre es
   la llamada: `EXTFEAT.PAS` (2408–2564) y `VPA4.PAS` (2247) tienen una variable
   local `line`, `SCREEN.PAS:1335` una constante local `line`, y `VPA4.PAS:385`
   un campo `detect`. Por eso, para los procedimientos con parámetros, la cifra
   de la tabla 1 cuenta solo apariciones seguidas de `(`.

`TESTS/inventory.py --where Simbolo` da fichero:línea de cada uso; `--unused`
lista los exportados que nadie usa; `--tsv` vuelca todo para procesarlo.

## 1. Tabla 1 — API Graph (procedimientos, funciones y punteros de función)

Firmas tal y como las declara `VENDOR/graphh.inc` (`-Mtp`: `string` es
*shortstring*, `smallint` 16 bits, `ColorType = word`). Los símbolos marcados
`(var)` son punteros de función que el driver rellena en `InitGraph`; para VPA
son llamadas normales. «Usos» cuenta solo el código enlazado; entre paréntesis,
el desglose por fichero. Prioridad: `v1` = necesario en la ABI v1;
`v2` = solo lo usa código hoy no enlazado; `no` = no se usa.

| Símbolo | Firma (`graphh.inc`) | Usos | Ficheros | Prio. | Compl. | Equivalencia prevista en el backend |
|---|---|---:|---|:-:|:-:|---|
| `OutTextXY` (var) | `procedure(x,y: SmallInt; const TextString: string)` | 1071 | VPA2 271, VPA3 136, VPA4 129, EXTFEAT 129, BUILDING 88, SCREEN 87, VCS 84, PLANSIM 82, MESSAGES 25, VPAINIT 14, REPORT 12, SCORES 12, VHLP 1, VPAEXIT 1 (+ TASKS* 32, DETAILS* 8, MSGWIN* 6, VPACC* 1) | v1 | **alta** | El envoltorio `VPAGraph.OutTextXY` convierte el shortstring a `PAnsiChar`+longitud y llama al plugin. El plugin rasteriza con la fuente, justificación y modo de escritura actuales (`SetTextStyle`, `SetTextJustify`, `SetWriteMode`); ver §6 para las tres fuentes en juego. Alta porque un píxel de diferencia en el trazado de `LITT_VPA.CHR` descuadra todo el mapa. |
| `SetColor` | `procedure SetColor(Color: ColorType)` | 648 | VPA2 151, VPA4 90, EXTFEAT 87, VPA3 82, SCREEN 73, BUILDING 41, VCS 32, MESSAGES 24, PLANSIM 24, TCOMBAT 14, SCORES 12, VPAINIT 8, REPORT 5, VHLP 4, VPAEXIT 1 (+ TASKS* 17, MSGWIN* 4, DETAILS* 2, VPACC* 1) | v1 | baja | Estado «color actual» (índice 0..255) del plugin. |
| `Line` (var) | `procedure(X1, Y1, X2, Y2: smallint)` | 270 | VPA2 92, BUILDING 41, EXTFEAT 40, TCOMBAT 26, VPA4 17, SCREEN 16, VPA3 16, SCORES 14, VCS 4, VPAINIT 2, PLANSIM 1, VHLP 1 (+ DETAILS* 1) | v1 | **alta** | Bresenham con el estilo (`SolidLn`, `DottedLn`, `DashedLn`, `UserBitLn` con patrón de 16 bits), grosor (`NormWidth`/`ThickWidth`) y modo de escritura actuales, recortado al *viewport*. Alta por el patrón de puntos: tiene que caer en las mismas fases que en BGI o cambian las líneas discontinuas del mapa. |
| `SetLineStyle` | `procedure SetLineStyle(LineStyle: word; Pattern: word; Thickness: word)` | 75 | VPA2 25, EXTFEAT 15, VPA3 11, SCREEN 6, VPA4 4, BUILDING 3, VCS 3, VHLP 2, TCOMBAT 2, MESSAGES 1, PLANSIM 1, SCORES 1, VPAINIT 1 (+ MSGWIN* 1, VPACC* 1, TASKS* 1) | v1 | baja | Estado de línea del plugin; `Pattern` solo cuenta con `UserBitLn`. |
| `PutImage` (var) | `procedure (X,Y: smallint; var Bitmap; BitBlt: Word)` | 39 | TCOMBAT 19, SCRSAVER 8, SCREEN 4, BUILDING 2, EXTFEAT 2, VCS 2, VPA2 1, VPA3 1 (+ TASKS* 1) | v1 | media | Recibe un puntero crudo al búfer de VPA con el formato de §5 y el modo `NormalPut`/`XORPut`/`OrPut` (los tres que se usan; `AndPut`/`NotPut` no). Recorta al *viewport* como ptcgraph. |
| `PutPixel` (var) | `procedure(X,Y: smallint; Color: ColorType)` | 38 | VPA2 21, SCREEN 7, TCOMBAT 5, EXTFEAT 2, VPAINIT 2, BUILDING 1 | v1 | baja | Píxel con color explícito, relativo al *viewport*, recortado. Es además la primitiva con la que VPA rasteriza **él mismo** la fuente 8×16 (§6). |
| `SetWriteMode` | `procedure SetWriteMode(WriteMode: smallint)` | 34 | TCOMBAT 9, VPA2 7, EXTFEAT 5, SCREEN 4, VPA4 4, MESSAGES 2, VPA3 2, BUILDING 1 | v1 | media | Estado `NormalPut`/`XORPut` que afecta a `Line`, `Rectangle`, `LineTo`, `LineRel`, `OutTextXY` y `Circle` (así lo hace ptcgraph). Restricción §2.3.5 de `WAYLAND.md`: es lo más fácil de hacer «casi bien». |
| `SetViewPort` | `procedure SetViewPort(X1, Y1, X2, Y2: smallint; Clip: Boolean)` | 31 | VPA3 18, VPA2 8, EXTFEAT 5 | v1 | media | Origen y recorte del plugin. Todas las primitivas de dibujo son relativas a él; `ClearDevice` no, `ClearViewPort` no se usa. |
| `SetTextJustify` | `procedure SetTextJustify(horiz,vert: word)` | 28 | VPA2 12, PLANSIM 3, SCORES 3, EXTFEAT 2, MESSAGES 2, SCREEN 2, VPA3 2, VPA4 2 (+ MSGWIN* 1, VPACC* 1) | v1 | baja | Estado de texto; combinaciones usadas: `LeftText`/`CenterText`/`RightText` × `TopText`/`BottomText`. |
| `Bar` | `procedure Bar(x1,y1,x2,y2: smallint)` | 21 | SCREEN 5, TCOMBAT 5, VPA4 5, VPA2 2, EXTFEAT 1, VCS 1, VHLP 1, VPAEXIT 1 (+ MSGWIN* 1, VPACC* 1) | v1 | baja | Relleno con el estilo de `SetFillStyle` (solo `SolidFill` se usa) y su color, **no** el color actual. |
| `Rectangle` | `procedure Rectangle(x1,y1,x2,y2: smallint)` | 17 | EXTFEAT 3, MESSAGES 2, SCORES 2, SCREEN 2, VPA2 2, BUILDING 1, PLANSIM 1, TCOMBAT 1, VHLP 1, VPAEXIT 1, VPAINIT 1 (+ MSGWIN* 1, VPACC* 1, TASKS* 1) | v1 | baja | Cuatro `Line` con el estilo actual (ptcgraph lo implementa así). |
| `ClearDevice` | `procedure ClearDevice` | 17 | EXTFEAT 5, TCOMBAT 4, PLANSIM 2, SCORES 2, VCS 2, BUILDING 1, SCRSAVER 1 | v1 | baja | Borra **toda** la superficie al color de fondo (0) ignorando el *viewport* y deja el cursor gráfico en (0,0). |
| `SetFillStyle` | `procedure SetFillStyle(Pattern: word; Color: ColorType)` | 16 | SCREEN 5, TCOMBAT 5, VPA2 2, EXTFEAT 1, VCS 1, VHLP 1, VPAEXIT 1 (+ MSGWIN* 1, VPACC* 1) | v1 | baja | Estado de relleno; solo `SolidFill`. Los otros 11 patrones y `SetFillPattern` quedan fuera. |
| `MoveTo` | `procedure MoveTo(X,Y: smallint)` | 14 | PLANSIM 5, SCORES 4, EXTFEAT 3, VPA2 2 | v1 | baja | Cursor gráfico (`CP`) del plugin, usado por `LineTo`/`LineRel`. |
| `SetTextStyle` | `procedure SetTextStyle(font,direction: word; charsize: word)` | 11 | VPA2 6, BUILDING 2, VPA3 2, SCREEN 1 (+ MSGWIN* 1) | v1 | media | Solo dos combinaciones: `(DefaultFont, HorizDir, 1)` y `(LittFont, HorizDir, 4)`. `VertDir` y otros tamaños no se usan. |
| `SetGraphMode` | `procedure SetGraphMode(Mode: smallint)` | 10 | BUILDING 2, INI 2, VCS 2, EXTFEAT 1, MESSAGES 1, SCRSAVER 1, TCOMBAT 1 | v1 | media | Ver §1.1: siempre como `SetGraphMode(GetGraphMode)` tras `RestoreCrtMode`, o blindado con `BadVideoOrMouse` (`TCOMBAT.PAS:1595`, modo 3). En la ABI es la mitad «reabrir» de *suspender/reanudar ventana*, no un cambio de modo. |
| `Circle` (var) | `procedure(X, Y: smallint; Radius: Word)` | 10 | VPA2 4, BUILDING 2, VPAINIT 2, TCOMBAT 1, VHLP 1 | v1 | media | Círculo de punto medio con el color y modo actuales. `VPAINIT.PAS:1355` lo captura con `GetImage` (8×8) y lo pega después: el trazado tiene que ser idéntico píxel a píxel al de ptcgraph. |
| `GetGraphMode` | `function GetGraphMode: smallint` | 9 | BUILDING 2, INI 2, VCS 2, EXTFEAT 1, MESSAGES 1, SCRSAVER 1 | v1 | baja | Solo como argumento de `SetGraphMode`. Con la ABI de §1.1 desaparece del código de VPA. |
| `RestoreCrtMode` | `procedure RestoreCrtMode` | 9 | BUILDING 2, INI 2, VCS 2, EXTFEAT 1, MESSAGES 1, SCRSAVER 1 | v1 | media | Mitad «suspender» de §1.1: cierra la ventana y devuelve la terminal para ejecutar un programa externo. |
| `LineRel` | `procedure LineRel(Dx, Dy: smallint)` | 9 | EXTFEAT 3, PLANSIM 3, SCORES 3 | v1 | baja | `Line` desde `CP`, mueve `CP`. Gráficas de estadísticas. |
| `LineTo` | `procedure LineTo(X,Y: smallint)` | 8 | PLANSIM 5, EXTFEAT 1, SCORES 1, VPA2 1 | v1 | baja | Ídem. |
| `SetRGBPalette` (var) | `procedure(ColorNum, RedValue, GreenValue, BlueValue: smallint)` | 7 | TCOMBAT 7 | v1 | baja | Escribe una entrada de la paleta de 256 (§7). |
| `GetViewSettings` | `procedure GetViewSettings(var viewport: ViewPortType)` | 6 | VPA2 3, VPA3 2, EXTFEAT 1 | v1 | baja | Devuelve el *viewport* actual; en la ABI, cinco enteros por referencia (el registro `ViewPortType` lo rellena el envoltorio). |
| `GetImage` (var) | `procedure(X1,Y1,X2,Y2: smallint; Var Bitmap)` | 5 | SCREEN 3, VPA3 1, VPAINIT 1 (+ TASKS* 1) | v1 | media | Escribe en un búfer de VPA con el formato de §5. Quien reserva es VPA (`WAYLAND.md` §2.3.9). |
| `ImageSize` (var) | `function (X1,Y1,X2,Y2: smallint): longint` | 5 | SCREEN 2, VPAINIT 2, VPA3 1 (+ TASKS* 1) | v1 | baja | `12 + w*h*2`, devuelto como 32 bits **sin excepción** (§2.3.4). |
| `GetPixel` (var) | `function(X,Y: smallint): ColorType` | 4 | VPA2 4 | v1 | baja | Lectura de un píxel relativo al *viewport*. |
| `InstallUserFont` | `function InstallUserFont(const FontFileName: string): smallint` | 1 | VPAINIT 1 | v1 | **alta** | `InstallUserFont('LITT_VPA.CHR')` → `LittFont`. Solo registra el nombre; el `.CHR` se carga en el primer `SetTextStyle`. El plugin necesita su propio cargador/rasterizador de `.CHR` con métricas idénticas (§6). Alta por eso, aunque sea una llamada. |
| `InitGraph` | `procedure InitGraph(var GraphDriver: smallint; var GraphMode: smallint; const PathToDriver: String)` | 1 | VPAINIT 1 (+ VHLPSHOW* 1) | v1 | media | `InitGraph(D8bit, m640x480, '')` con `VPAForceScale` fijado antes. En la ABI: `Init(width=640, height=480, scale_pct)` → abre la ventana. |
| `CloseGraph` | `procedure Closegraph` | 1 | SCREEN 1 (+ VHLPSHOW* 1) | v1 | baja | Cierra la ventana. `SCREEN.PAS:288` llama antes a `ReleaseFullscreen`. |
| `GraphResult` | `function GraphResult: smallint` | 1 | VPAINIT 1 (+ VHLPSHOW* 2) | v1 | baja | Solo se compara con `grOk` tras `InitGraph` (`GrErr`). En la ABI, el código de retorno de `Init`. |
| `GetRGBPalette` (var) | `procedure(ColorNum: smallint; var RedValue, GreenValue, BlueValue: smallint)` | 1 | TCOMBAT 1 | v1 | baja | Lee una entrada de paleta (salvado de 0..15 en `TCombatInit`). |
| `GetColor` | `function GetColor: ColorType` | 1 | VPA4 1 | v1 | baja | Devuelve el color actual. |
| `Ellipse` | `procedure Ellipse(X,Y: smallint; stAngle, EndAngle: word; XRadius, YRadius: word)` | 1 | TCOMBAT 1 | v1 | media | Una llamada, en el combate. Se puede sustituir por `Circle` si el radio es igual en ambos ejes; se decide en la Fase 2 mirando la llamada. |
| `VPAForceScale` (var, `ptcgraph.pp`) | `VPAForceScale: LongInt = 0` | 1 | VPAINIT 1 | v1 | baja | Añadido del port: porcentaje de escala que ptcgraph aplica al abrir la ventana. Pasa a ser parámetro de `Init`. |
| `VPADumpEnabled` (`ptcgraph.pp`) | `function VPADumpEnabled: Boolean` | 1 | KEYBOARD 1 | v1 | baja | Añadido de la Fase 0 (T0.4). El volcado del *framebuffer* a `.ppm`/`.pal` es exactamente lo que la Fase 11 necesita del plugin nuevo: entra en la ABI como `DumpFrame`. |
| `VPADumpFrame` (`ptcgraph.pp`) | `function VPADumpFrame: LongInt` | 1 | KEYBOARD 1 | v1 | baja | Ídem. |
| `TextWidth` | `function TextWidth(const TextString: string): word` | 0 | (MSGWIN* 4) | v2 | baja | Solo en `CC/MSGWIN.PAS`, no enlazado. Trivial de añadir cuando haga falta. |
| `RegisterBGIDriver` | `function RegisterBGIDriver(driver: pointer): smallint` | 0 | (VHLPSHOW* 1) | v2 | — | Solo la utilidad `VHLPSHOW`. Sin sentido en la ABI (no hay `.bgi`). |
| `GraphErrorMsg` | `function GraphErrorMsg(ErrorCode: smallint): string` | 0 | (VHLPSHOW* 1) | v2 | — | Ídem; en `VPAINIT.PAS:1291` está comentado. |

### 1.1 El patrón «suspender y reanudar la ventana»

`RestoreCrtMode` y `SetGraphMode(GetGraphMode)` no aparecen sueltos: van en
pareja, siempre para ejecutar algo externo (editor, comando, salvapantallas)
y volver, y **siempre** seguidos en Linux de la terna de `xfocus`:

| Sitio | Motivo |
|---|---|
| `VPA/INI.PAS:337-350` | Ctrl-O → ejecutar programa externo |
| `VPA/INI.PAS:381-412` | Ctrl-O → *Edit file* (`$VISUAL`/`$EDITOR`) |
| `VPA/BUILDING.PAS:1156-1157`, `:1186-1187` | lanzar programa externo desde la pantalla de base |
| `VPA/MESSAGES.PAS:1469-1470` | editor externo de mensajes |
| `VPA/EXTFEAT.PAS:4724-4725` | programa externo de funciones extendidas |
| `VPA/VCS.PAS:1104-1105`, `:1146-1147` | comandos VCS externos |
| `VPA/SCRSAVER.PAS:269-270` | vuelta del salvapantallas, solo si `BadVideoOrMouse` |
| `VPA/TCOMBAT.PAS:1595` | `SetGraphMode(3)` (modo texto DOS), solo si `BadVideoOrMouse` |

Consecuencia para la Fase 2: la ABI ofrece **una** pareja `Suspend`/`Resume`
(cerrar ventana y devolver terminal / reabrir ventana **y** rehacer foco,
escala y pantalla completa) en lugar de resucitar `SetGraphMode` (§2.3.8 de
`WAYLAND.md`). Los ocho sitios se migran a esa pareja en la Fase 6 y las tres
llamadas repetidas a `xfocus` desaparecen del código de VPA.

## 2. Tabla 2 — Constantes y tipos de `ptcgraph` que usa VPA

Todos tienen que reexportarlos `VPAGraph` con **el mismo valor** (los valores
de color viajan por `SetColor` y por los búferes de imagen; los de estilo y
modo, por la ABI). Usos en código enlazado.

| Símbolo | Valor | Usos | Ficheros (enlazados) |
|---|---|---:|---|
| `Black` … `White` (16 colores) | 0..15 | — | ver desglose |
| `White` | 15 | 235 | 15 ficheros; `SCREEN` 39, `VPA2` 39, `EXTFEAT` 33 |
| `Yellow` | 14 | 142 | 15 ficheros; `VPA3` 35, `VPA4` 34 |
| `LightGray` | 7 | 88 | 12 ficheros |
| `DarkGray` | 8 | 68 | 9 ficheros |
| `Black` | 0 | 63 | 9 ficheros (`TCOMBAT` 13) |
| `Green` | 2 | 57 | 7 ficheros |
| `LightRed` | 12 | 53 | 13 ficheros |
| `Red` | 4 | 46 | 7 ficheros |
| `LightGreen` | 10 | 28 | 8 ficheros |
| `LightBlue` | 9 | 15 | 8 ficheros |
| `LightMagenta` | 13 | 13 | 7 ficheros |
| `Magenta` | 5 | 12 | 6 ficheros |
| `Cyan` | 3 | 10 | 6 ficheros |
| `Blue` | 1 | 8 | 4 ficheros |
| `Brown` | 6 | 8 | 6 ficheros |
| `LightCyan` | 11 | 5 | 4 ficheros |
| `NormWidth` | 1 | 69 | 13 ficheros |
| `ThickWidth` | 3 | 4 | SCREEN, VCS, VPA2 |
| `SolidLn` | 0 | 58 | 14 ficheros |
| `DottedLn` | 1 | 7 | EXTFEAT, VPA2, VPA3 |
| `DashedLn` | 3 | 5 | VPA2 |
| `UserBitLn` | 4 | 6 | BUILDING, VPA2, VPA3 |
| `NormalPut` | 0 | 50 | 11 ficheros (`TCOMBAT` 21) |
| `XORPut` | 1 | 21 | 8 ficheros (`SCRSAVER` 6) |
| `OrPut` | 2 | 3 | TCOMBAT |
| `ClipOn` | `true` | 23 | EXTFEAT, VPA2, VPA3 |
| `ClipOff` | `false` | 1 | EXTFEAT |
| `LeftText` / `CenterText` / `RightText` | 0 / 1 / 2 | 14 / 13 / 5 | 8 / 7 / 5 ficheros |
| `TopText` / `BottomText` | 2 / 0 | 19 / 1 | 9 / 1 ficheros |
| `HorizDir` | 0 | 11 | BUILDING, SCREEN, VPA2, VPA3 |
| `DefaultFont` | 0 | 6 | BUILDING, SCREEN, VPA2, VPA3 |
| `SmallFont` | 2 | 2 | SCREEN (valor inicial de `LittFont`), VPAINIT (*fallback*) |
| `SolidFill` | 1 | 10 | 5 ficheros |
| `D8bit` | 15 | 1 | VPAINIT (`gd`) |
| `m640x480` | `detectMode + 9` (30009) | 1 | VPAINIT (`gm`) |
| `grOk` | 0 | 1 | VPAINIT |
| `ViewPortType` | `record x1,y1,x2,y2: smallint; Clip: boolean end` | 6 | EXTFEAT, VPA2, VPA3 |
| `ColorType` | `word` | 2 | SCREEN |

Notas:

- `D8bit`, `m640x480` y `grOk` solo existen para la llamada única a
  `InitGraph`; cuando `Init` tome ancho, alto y escala como parámetros, dejan
  de hacer falta en VPA. Se reexportan igualmente en la v1 para que el `uses`
  se pueda cambiar de una pieza y limpiar después.
- `SmallFont` es el valor que `LittFont` conserva si `LITT_VPA.CHR` no carga
  (`VPAINIT.PAS:1348`). ptcgraph tampoco tiene esa fuente incorporada: buscaría
  `LITT.CHR` (el nombre que `graph.inc` da a la fuente 2) y, al no encontrarlo, dibuja con `DefaultFont`. Es decir, el
  *fallback* real es el bitmap 8×8; conviene que la ABI lo diga explícitamente.
- No se usa ningún otro tipo de `graphh.inc` (`PaletteType`,
  `LineSettingsType`, `TextSettingsType`, `FillSettingsType`, `PointType`,
  `ArcCoordsType`, `FillPatternType`, `PModeInfo`…).

## 3. Tabla 3 — Teclado (`ptccrt`)

Solo `UNIT/KEYBOARD.PAS` toca `ptccrt`; todo VPA lee teclas a través de
`Keyboard`. Los 70 `ReadKey` y 39 `KeyPressed` de la tabla vieja eran los de
`Keyboard`, no los de `ptccrt`.

| Símbolo de `ptccrt` | Firma | Usos | Desde | Qué necesita del backend |
|---|---|---:|---|---|
| `ReadKey` | `function ReadKey: Char` | 5 | `RawReadKey` (`KEYBOARD.PAS:45,47`) | Siguiente tecla del búfer, bloqueante (duerme 1 ms entre sondeos). Convención TP7: ASCII, o `#0` seguido de scancode extendido. |
| `KeyPressed` | `function KeyPressed: Boolean` | 5 | `FastKeyPressed`, `KeyPressed` (`:65,73`) | ¿Hay tecla en el búfer? Vacía la cola de eventos de la ventana al preguntar. |
| `PTCLastKbdFlags` | `PTCLastKbdFlags: Byte = 0` | 2 | `KbdFlags` (`:99,101`) | Modificadores de la **última pulsación** (Shift=3, Ctrl=4, Alt=8, estilo BIOS `0040:0017`). Solo se usa si no hay conexión X (`XReady` falso). |
| `PTCQuitNoSave` | `PTCQuitNoSave: Boolean = False` | 1 | `KbdQuitNoSave` (`:110`) | True si la salida pedida fue Ctrl-Alt-X (sin guardar); False para Alt-X y para el botón [X] de la ventana. |
| `PTCCtrlDown` | `PTCCtrlDown: Boolean = False` | 0 | — | Interno de ptccrt (rastrea Ctrl entre eventos); no lo usa VPA. |

### 3.1 Camino completo de una pulsación

```
ventana X11 (ptc, hilo de eventos)  →  cola IPTCEvent del PTCWrapperObject
   → ptccrt.GetKeyEvents            traduce IPTCKeyEvent a bytes TP7 (KeyBufAdd)
   → ptccrt.KeyPressed / ReadKey    sirve el búfer de bytes
   → Keyboard.RawReadKey            char → word (ascii en byte bajo, o scancode en byte alto)
   → Keyboard.ReadKey / PreviewKey  búfer de retroceso de una tecla
   → los `case` de VPA              ($4D00 = Derecha, $2D00 = Alt-X, $8A00 = Ctrl-F12…)
```

Lo que `GetKeyEvents` (`VENDOR/ptccrt.pp:124-540`) decide y que el backend
nuevo tiene que reproducir **con los mismos códigos**:

- **Modificadores de la pulsación** → `PTCLastKbdFlags` (`:150-153`).
- **Botón [X] de la ventana** (`PTCCloseEvent`) → `#0#45` (Alt-X, salir
  guardando) con `PTCQuitNoSave := False` (`:134-141`).
- **Alt-X** → `#0#45` y `PTCQuitNoSave := KeyEv.Control or PTCCtrlDown`
  (`:208`): Ctrl-Alt-X sale sin guardar.
- **Alt-flechas** → `$9800/$9B00/$9D00/$A000` también en `kmTP7` (`:273-276`):
  paneo del mapa y ajustes ±100.
- **Ctrl-'+' y Ctrl-'-'** → `#0#144` (`$9000`) y `#0#142` (`$8E00`) mirando
  `KeyEv.Unicode`, **no** el código de tecla (`:312-315`). Es el arreglo de
  3.67.5 para distribuciones no estadounidenses: en `es`, `de`, `fr`… el `+`
  de la fila principal llega como `PTCKEY_UNDEFINED` (su keysym `XK_plus` no
  está en la tabla de ptc) y en `us`/`ru` como Shift+`PTCKEY_EQUALS`; el `-`
  devolvía el `#31` del TP7 de DOS. **Requisito de la ABI:** el evento de
  teclado lleva el carácter Unicode además del código de tecla, y la
  traducción de Ctrl-+/- se hace sobre el carácter.
- **F11/F12 y Ctrl-Tab** en `kmTP7` (`:329,410,472,507`): `$8500`, `$8700`,
  `$8A00`… que el ptccrt original solo emitía en `kmGO32`.
- **Caracteres imprimibles** solo entre 32 y 127 (`:489,532`): VPA no recibe
  acentos ni cirílico por teclado; el ruso entra por su fuente, no por
  `ReadKey`.

`KeyMode` es siempre `kmTP7` (VPA no lo toca). `Delay`, `Sound`, `NoSound`
y `TextAttr` que aparecen en VPA son los de `UNIT/AUXF.PAS` y `VPA/SCREEN.PAS`,
no los de `ptccrt`.

### 3.2 Lo que el teclado pide a `xfocus`

`KbdFlags` prefiere `xfocus.KbdModifiers` (estado **actual** de Shift/Ctrl/Alt
por `XQueryPointer` sobre la raíz) y solo cae a `PTCLastKbdFlags` sin conexión
X. Hace falta porque VPA combina ratón+modificador (zoom del mapa con Shift/Ctrl
y botón central), y ahí no hay «última pulsación» que consultar. En la ABI:
`GetModifiers` devuelve el estado actual, y el plugin lo mantiene a partir de
sus propios eventos de teclado en vez de preguntar al servidor.

## 4. Tabla 4 — Ratón (`ptcmouse`)

Solo `UNIT/MOUSE.PAS` toca `ptcmouse`. `ptcmouse` es **por eventos**: cada
función vacía la cola de `IPTCMouseEvent` y devuelve el último estado conocido;
las coordenadas son **píxeles de ventana** (de ahí el mapeo de §5 de la tabla
siguiente).

| Símbolo de `ptcmouse` | Firma | Usos | Desde | Qué necesita del backend |
|---|---|---:|---|---|
| `InitMouse` | `function InitMouse: Boolean` | 1 | `EnableMouse` (`MOUSE.PAS:98`) | Siempre True en ptc (`MouseFound`). |
| `ShowMouse` / `HideMouse` | `procedure` | 5 / 5 | `EnableMouse`, `DisableMouse`, `ShowMouse`, `HideMouse`, `SuspendMouse`, `ResumeMouse` | Mostrar/ocultar el cursor **del sistema** (`Option('show cursor')`). VPA dibuja su propia diana; el cursor del sistema se oculta durante el juego. |
| `GetMouseState` | `procedure GetMouseState(var x, y, buttons: LongInt)` | 1 | `PollMouse` (`:159`) | Posición en píxeles de ventana y máscara de botones (`LButton=1`, `RButton=2`, `MButton=4`). |
| `SetMousePos` | `procedure SetMousePos(x,y: LongInt)` | 1 | `MoveMouse` (`:139`) | *Warp* del puntero físico a píxeles de ventana. ptcmouse (modificado en el port) actualiza también su posición interna, porque sin evento real `GetMouseState` seguiría devolviendo la anterior. |
| `LPressed`, `RPressed`, `MPressed`, `LButton`, `RButton`, `MButton`, `MouseFound` | | 0 | — | No usados por VPA (`MOUSE.PAS` enmascara `lb and $07` directamente). |

### 4.1 Lo que `MOUSE.PAS` emula por software (y que la ABI no necesita)

- **Sondeo, no interrupción.** No hay *handler* de interrupción como en DOS:
  `PollMouse` se llama desde `Keyboard.KeyPressed` (en cada espera de entrada)
  y desde el bucle del mapa (`VPA2.PAS:4072`), y genera los eventos
  `EvMouseMove`/`EvLtPress`… comparando con el estado anterior.
- **Rango del cursor.** `SetMouseRange(0,0,479,479)` (`VPAINIT.PAS:1445`) se
  guarda y `PollMouse` recorta las coordenadas a ese rectángulo. Sin *warp*
  del puntero físico: se probó y producía un bucle de realimentación que
  clavaba el ratón en el borde. `ptcmouse` no expone limitación de rango y
  la ABI tampoco necesita hacerlo.
- **StickyMouse** (`Screen.StickyMouseRange`, 2 px por defecto, ajustable en
  `VPA.INI`) es lógica de VPA sobre `MouseX`/`MouseY`; lo único que pide al
  backend es el *warp* (`MoveMouseTo` → `MoveMouse` → `SetMousePos`), en 11
  sitios de `BUILDING`, `EXTFEAT`, `MESSAGES` y `DETAILS*`.
- `SetPointerShape`, `SetMouseSensitivity`, `AllocateStatusBuffer`,
  `SaveMouseStatus`, `RestoreMouseStatus`: vacíos en el port. La forma del
  cursor DOS no se porta; VPA dibuja la diana con `PutPixel`/`Line`.
- **Posición inicial** `(160,100)` en `EnableMouse` es la del driver DOS; no
  depende del backend.

Contrato mínimo de ratón para la ABI: `GetMouseState(x, y, buttons)` en
píxeles de **superficie 640×480** (que el plugin haga el mapeo, no VPA),
`WarpMouse(x, y)` en las mismas coordenadas, y `ShowCursor(bool)`.

## 5. Tabla 5 — Ventana y foco (`xfocus`)

Las 19 llamadas de `WAYLAND.md` §2.1, confirmadas una a una. `xfocus`
mantiene su **propia** conexión X (`gDpy`) y encuentra la ventana de ptc por
título (`FindWin`: `_NET_CLIENT_LIST` y luego `XQueryTree`, comparando con
`ParamStr(0)`). Para cada función, qué hace hoy con Xlib y qué necesita en
realidad del servidor gráfico, que es lo que la ABI debe ofrecer.

| Función | Llamadas | Hoy (Xlib) | Lo que necesita de verdad |
|---|---|---|---|
| `ResolveScale` | `VPAINIT.PAS:1339` | Abre y cierra un `Display` propio solo para `XDisplayWidth/Height`; interpreta `VPA_SCALE` (§2.3.10); recorta a lo que cabe en 4:3; fija `gWantFullscreen`. | **Tamaño de la pantalla** (o del *output* actual) antes de crear la ventana. La interpretación de `VPA_SCALE` es lógica de VPA y se queda en el núcleo (`GRAPH/`), no en el plugin. |
| `GrabInputFocus` | `VPAINIT.PAS:1812`, `INI.PAS:348`, `INI.PAS:410` | Busca la ventana por título hasta 20×50 ms; `XRaiseWindow`, `XSetInputFocus`, `_NET_ACTIVE_WINDOW`. Deja `gDpy` abierto. | **Nada**, si la ventana la crea el propio plugin y pide el foco al mapearla. En Wayland no existe «pedir el foco»; el compositor lo da a la ventana nueva. Desaparece de la ABI: `Init`/`Resume` lo hacen implícitamente. |
| `ApplyWindowScale` | `VPAINIT.PAS:1813`, `INI.PAS:349`, `INI.PAS:411` | `XGetWindowAttributes`: si la ventana es mayor de 640×480 activa el escalado de ratón y cachea `gWinW/gWinH`. | Nada: el plugin sabe su escala y entrega el ratón ya en coordenadas de superficie (§4). Desaparece. |
| `WantFullscreen` | `VPAINIT.PAS:1814`, `INI.PAS:350`, `INI.PAS:412` | Devuelve `gWantFullscreen`. | Lógica de VPA (resultado de `ResolveScale`). Se queda en el núcleo. |
| `RequestFullscreen` | los mismos tres sitios | Espera a que la ventana esté mapeada (≤2 s), fondo negro, relaja `WMNormalHints`, `_NET_WM_STATE_FULLSCREEN` por propiedad y por `ClientMessage`. | **`SetFullscreen(true)`** en la ABI, que el plugin implementa con `xdg_toplevel.set_fullscreen` (Wayland) o EWMH (X11). El «fondo negro alrededor del 4:3» lo dibuja el plugin. |
| `ReleaseFullscreen` | `SCREEN.PAS:288` | Quita la propiedad y envía `_NET_WM_STATE_REMOVE`, antes de `CloseGraph`. | `SetFullscreen(false)`; opcional, al destruir la ventana el estado desaparece. |
| `PointerInsideWindow` | `VPA2.PAS:4078` | `XQueryPointer` sobre la ventana + `XGetWindowAttributes`. Evita el auto-scroll infinito cuando el puntero ha salido. | **Un bit «el puntero está dentro»** que el plugin mantiene con sus eventos *enter/leave* (`wl_pointer.enter/leave`, `EnterNotify/LeaveNotify`). Entra en `GetMouseState` como flag. |
| `MapSurfaceToWindow` | `MOUSE.PAS:155` | Superficie → ventana para el *warp* (`(x*gWinW) div 640 + medio bloque`). | Nada: `WarpMouse` recibe coordenadas de superficie (§4). El «centro del bloque escalado» es detalle del plugin. |
| `MapMouseToSurface` | `MOUSE.PAS:178` | Ventana → superficie, con recorte a 0..639/0..479. | Nada: `GetMouseState` devuelve superficie. |
| `XReady` | `KEYBOARD.PAS:83` | `gDpy <> nil`. | Desaparece con `GetModifiers` (§3.2). |
| `KbdModifiers` | `KEYBOARD.PAS:84` | `XQueryPointer` sobre la raíz → máscara Shift/Control/Mod1. | `GetModifiers` en la ABI: estado actual que el plugin lleva desde sus eventos de teclado. |

No usados (declarados en `xfocus` pero sin llamadas): `FullscreenRequested`
(lee `VPA_FULLSCREEN`/`VPA_VIDEO`, superado por `VPA_SCALE=fullscreen`),
`ReleaseInputFocus` (nadie cierra `gDpy`: se cierra con el proceso) y
`MakeBlankCursor` (privado; el cursor se oculta vía `ptcmouse.HideMouse`).

**Lectura para la Fase 2:** de las once funciones, solo cuatro son de verdad
peticiones al servidor gráfico —tamaño de pantalla, pantalla completa, puntero
dentro/fuera y modificadores actuales— y las otras siete son *parches* para
alcanzar desde fuera una ventana que ptc crea sin dar acceso a ella. Con la
ventana dentro del plugin, la mitad «menos obvia» de la ABI queda en:
`GetScreenSize`, `SetFullscreen`, el bit `pointer_inside` en el estado del
ratón y `GetModifiers`.

### 5.1 Dependencia oculta: `cthreads`

`VPA/VPA.PAS:8` pone `cthreads` primero en el `uses` porque ptc corre el bucle
de eventos X11 en un hilo. No es un símbolo, pero cruza la frontera: cuando
ptcgraph viva en el `.so`, hay que decidir qué RTL gestiona los hilos (tarea
`T5.9`). Queda anotado aquí para que T1.9 no lo dé por «no encontrado».

## 6. Contrato de fuentes

Tres fuentes distintas, tres caminos distintos:

| Fuente | Quién rasteriza | Dónde | Métrica |
|---|---|---|---|
| `DefaultFont` (bitmap 8×8 de BGI) | ptcgraph (`fontdata.inc`) | `SetTextStyle(DefaultFont,HorizDir,1)` + `OutTextXY` | 8×8 por carácter, tamaño 1 |
| `LittFont` = `InstallUserFont('LITT_VPA.CHR')` (vectorial) | ptcgraph (`gtext.inc`, trazos `.CHR`) | `SetTextStyle(LittFont,HorizDir,4)` en `VPA2.PAS:774,813,903`, `VPA3.PAS:3127`, `BUILDING.PAS:244`; etiquetas del mapa | tamaño 4 → factor `4/4`; anchos por carácter del `.CHR` |
| `StandardFont` 8×16 (`VPA/RUSFONT.INC`, o `FontName` de la configuración) | **VPA mismo** con `PutPixel` (`SCREEN.PAS:314,339`) | pantalla de texto emulada (`WriteXY`, `TextAttr`) | 8×16; no pasa por `OutTextXY` |

Lo que importa para el backend: (1) `OutTextXY` con `DefaultFont` tiene que
dar los mismos 8×8 que `fontdata.inc`; (2) el rasterizador de `.CHR` tiene que
producir los mismos trazos (`Decode` y el escalado de `gtext.inc`) o las
etiquetas del mapa se descuadran; (3) la fuente rusa **no** es problema del
backend: solo necesita `PutPixel`. Las imágenes doradas de la Fase 0 cubren las dos
primeras (mapa con etiquetas y paneles); si ninguna escena ejercita la fuente
rusa, la Fase 11 tendrá que añadir una.

## 7. Contrato de formato de imagen (`GetImage`/`PutImage`/`ImageSize`)

Definido por `VENDOR/ptcgraph.pp` (`PTC_GetImageProc_8bpp`,
`ptc_PutImageproc_8bpp`) y `VENDOR/graph.inc` (`DefaultImageSize`), y
**fijado en piedra** porque VPA lo construye a mano:

```
offset  tamaño   contenido
0       longint  ancho en píxeles (w)
4       longint  alto en píxeles (h)
8       longint  reservado, siempre 0
12      w*h      word por píxel, fila a fila, valor = índice de paleta (0..255)
                 (ptcgraph enmascara con ColorMask al leer)
tamaño total = 12 + w*h*2  (ImageSize, longint)
```

Sitios que lo escriben o leen sin pasar por `GetImage`:

- `VPA/TCOMBAT.PAS:36` — `ImgSize = 12 + 104*104*2`.
- `VPA/TCOMBAT.PAS:1350-1361` (`LoadPic`) — `FillChar(ib^,12,0)`, ancho en
  bytes 0-1, alto en 4-5, y luego `ib^[k] := buf^[y,x]; ib^[k+1] := 0`.
- `VPA/TCOMBAT.PAS:1801-1835` — ídem para el disco del planeta (`diam`).
- `VPA/TCOMBAT.PAS:361-366` — `ImgW`/`ImgH` leen los bytes 0-1 y 4-5.
- `VPA/EXTFEAT.PAS:4468-4474` (`DrawPic`) — lee el ancho como `img[lr]^[1]`
  y el alto como `img[lr]^[3]` (índices de `word`) y llama a `PutImage`.
- `VPA/TCOMBAT.PAS:407-440` (`convertImage`) — la rama `useSVGA` (hoy
  siempre falsa en Linux) convierte al formato de un byte por píxel.

Reglas que se derivan: el plugin acepta y produce **exactamente** ese diseño
(little-endian, `longint` de 32 bits, `word` de 16); nunca reserva ni libera
esos búferes (§2.3.9); `ImageSize` devuelve 32 bits (§2.3.4, la corrupción de
`MenuSize` en 3.67.5); y `PutImage` recorta al *viewport* como ptcgraph, porque
`SCRSAVER` pega imágenes que se salen.

Modos de `PutImage` usados: `NormalPut` (copia), `XORPut` (`SCRSAVER`,
`SCREEN`, `TCOMBAT`, `VPA2`…) y `OrPut` (`TCOMBAT`). `AndPut` y `NotPut`, no.

## 8. Contrato de paleta

- Modo `D8bit`: 256 entradas RGB de 8 bits. Al arrancar, ptcgraph carga la
  paleta VGA por defecto (0..15 con los colores de la tabla 2 y el resto la
  escala estándar de 256 de BGI). VPA no la toca fuera del combate, así que
  **la paleta inicial del plugin tiene que ser la misma** o cambian todos los
  colores del juego. Está en `TESTS/golden/*.pal` (T0.4) para comprobarlo.
- **Combate** (`VPA/TCOMBAT.PAS`): `TCombatInit` (`:1571-1576`) salva las
  entradas 0..15 con `GetRGBPalette`; `SetPal` (`:1431-1446`) escribe 1..15
  desde `pal[i,1..3]`, que vienen de los ficheros de sprites como **6 bits
  (0..63) en orden R,B,G** (`LoadPic`, `:1263-1265`), con la conversión
  `SetRGBPalette(i, 4*pal[i,1], 4*pal[i,3], 4*pal[i,2])` (×4 y permutación
  B↔G); además fija cuatro índices libres para el disco del planeta
  (`clPlSalmon`…`clPlMid`, 208..211); `TCombatFinish` (`:1586-1589`) restaura
  0..15. Las paletas `VCRpal`/`PLpal` (`:70`) son constantes del programa,
  también en R,B,G de 6 bits.
- `SetRGBPalette` recibe `smallint` 0..255 por canal; en la ABI, cuatro
  `Int32` (índice, r, g, b) y su inverso con tres salidas por referencia.
- `SetPalette`, `SetAllPalette`, `GetPalette`, `GetDefaultPalette`,
  `PaletteType` y `SetBkColor`/`GetBkColor`: no se usan; el fondo es siempre
  el índice 0.

## 9. Símbolos declarados y no usados: fuera de la ABI v1

Decisión explícita: **ninguno de estos entra en la v1**. Si aparece una
necesidad se añade con su tarea `T*` y su prueba, no antes.

**Dibujo (`graphh.inc`):** `Arc`, `PieSlice`, `Sector`, `FillEllipse`,
`FillPoly`, `DrawPoly`, `FloodFill`, `Bar3D`, `GetArcCoords`, `GetAspectRatio`,
`SetAspectRatio`, `MoveRel`, `GetX`, `GetY`, `HLine`, `VLine`, `PatternLine`,
`InternalEllipse`, `DirectPutPixel`, `GetScanLine`, `ClearViewPort`,
`GraphDefaults`, `SetFillPattern`, `GetFillSettings`, `GetFillPattern`,
`GetLineSettings`, `SetWriteModeEx`, `SetBkColor`, `GetBkColor`, `GetMaxColor`,
`SetPalette`, `GetPalette`, `GetPaletteSize`, `GetDefaultPalette`,
`SetAllPalette`, `SetActivePage`, `SetVisualPage`.

**Texto:** `OutText`, `TextHeight`, `TextWidth` (v2, `MSGWIN*`),
`GetTextSettings`, `SetUserCharSize`, `RegisterBGIfont`,
`GraphStringTransTable`, `AnsiToASCIITransTable`, `DrawTextBackground`.

**Modos y drivers:** `DetectGraph`, `GetModeName`, `GetMaxMode`,
`GetModeRange`, `GetDriverName`, `GetMaxX`, `GetMaxY`, `InstallUserDriver`,
`RegisterBGIDriver` (v2, `VHLPSHOW*`), `GraphErrorMsg` (v2, `VHLPSHOW*`),
`queryadapterinfo`, `InstallUserMode`, `SetDirectVideo`, `GetDirectVideo`,
`SaveVideoState`, `RestoreVideoState`, `GraphFreeMemPtr`, `GraphGetMemPtr`,
todas las constantes de driver y modo salvo `D8bit`/`m640x480`/`Detect`
(`Detect` solo en `VHLPSHOW*`), todos los `gr*` salvo `grOk`, `WindowTitle`,
`FullscreenGraph`, `PTCWrapperObject`.

**Teclado (`ptccrt`):** `PTCCtrlDown`, `KeyMode`, `DirectVideo`, `TextAttr`,
`ClrScr`, `ClrEol`, `GotoXY`, `TextColor`, `TextBackground`, `Delay`, `Sound`,
`NoSound` (VPA usa los suyos de `AUXF`).

**Ratón (`ptcmouse`):** `LPressed`, `RPressed`, `MPressed`, `LButton`,
`RButton`, `MButton`, `MouseFound`, y todo el bloque comentado
(`SetMouseXRange`…).

**Ventana (`xfocus`):** `FullscreenRequested`, `ReleaseInputFocus`.

`GetMaxX`/`GetMaxY` merecen una nota: VPA tiene 640×480 cableado en todas
partes (`SetViewPort(0,0,639,479)`, `SetMouseRange(0,0,479,479)`), así que la
ABI no necesita consultas de tamaño de superficie; el tamaño es parámetro de
`Init`.

## 10. Revisión cruzada (T1.9)

1. `TESTS/inventory.py` recorre **los 350 símbolos** que exportan
   `ptcgraph`+`graphh.inc`, los 21 de `ptccrt`, los 12 de `ptcmouse` y los 13
   de `xfocus`, y todos los que tienen algún uso en `VPA/`, `UNIT/`, `CC/` y
   `VHLP/` están en las tablas 1–5 (los de código no enlazado, marcados `*`).
2. `grep -i` sobre los mismos directorios de `ptc`, `ptcwrapper`, `IPTC*`,
   `TPTC*`, `PTCWrapperObject`, `WindowTitle`, `FullscreenGraph`,
   `InstallUserMode`, `x`, `xlib`, `xutil`, `xatom`, `X[A-Z]*(`: **ningún**
   fichero fuera de `UNIT/xfocus.pas` los nombra. La única unidad de VPA que
   habla Xlib es `xfocus`, y sus 49 llamadas a `X*` (27 funciones distintas) están todas cubiertas por
   la tabla 5 (`ResolveScale`, `ApplyWindowScale`, `RequestFullscreen`,
   `ReleaseFullscreen`, `UpdateWindowSize`, `PointerInsideWindow`,
   `KbdModifiers`, `FindWin`, `MakeBlankCursor`, `GrabInputFocus`,
   `ReleaseInputFocus`).
3. Fuera de los símbolos: `cthreads` (§5.1) y las variables de entorno que
   lee la frontera hoy —`VPA_SCALE` (`xfocus.ResolveScale`), `VPA_GRAPH_DUMP`
   (`ptcgraph.VPADumpEnabled`), `VPA_FULLSCREEN`/`VPA_VIDEO` (sin usar)—
   quedan anotadas para que la Fase 4 (selección de backend) las contemple.

**Resultado:** nada nuevo. Criterio de aceptación de la Fase 1 cumplido.

## 11. Lo que cambia respecto a `WAYLAND.md` §2 (resumen para la Fase 2)

- La API Graph de la v1 son **32 entradas** (tabla 1 sin las `v2`), no 40; y
  cuatro de ellas (`SetGraphMode`, `GetGraphMode`, `RestoreCrtMode`,
  `GraphResult`) se funden en `Suspend`/`Resume` y el retorno de `Init`.
- La frontera de ventana son **cuatro** peticiones (`GetScreenSize`,
  `SetFullscreen`, `pointer_inside`, `GetModifiers`), no once funciones.
- El teclado exige el **carácter Unicode** en el evento, no solo el código.
- El ratón se entrega en coordenadas de **superficie**; el mapeo de escala es
  del plugin.
- Entran en la ABI dos añadidos del port que hoy viven en `ptcgraph.pp`:
  la escala (`VPAForceScale` → parámetro de `Init`) y el volcado
  (`VPADumpFrame`), que es la herramienta de la Fase 11.
- `Ellipse` (una llamada) y `TextWidth` (solo `MSGWIN*`) son las únicas
  decisiones abiertas; se toman en T2.1 mirando el sitio.
