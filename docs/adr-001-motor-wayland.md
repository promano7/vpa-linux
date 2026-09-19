# ADR-001 — Motor de dibujo del plugin Wayland

| | |
|---|---|
| Estado | **Aceptada** — 2026-09-19 |
| Decisión | **Vía B**: consola PTC sobre SDL3. La vía A queda descartada como plan y documentada como contingencia |
| Registro | D-06 en la sección 8 de `WAYLAND.md` |
| Tareas | T7.1 a T7.6 |

## 1. Contexto

`libvpagraph-wayland.so` tiene que dibujar exactamente lo mismo que
`libvpagraph-x11.so`. La sección 4 de `WAYLAND.md` dejó dos caminos abiertos:

- **Vía A** — framebuffer propio de 8 bits y reimplementación de las primitivas
  BGI, presentado con SDL3.
- **Vía B** — una consola de plataforma nueva para PTCPas (`VENDOR/ptc/sdl/`)
  sobre SDL3, reutilizando sin tocar todo el dibujo de `ptcgraph`.

La recomendación previa era la B, pero por intuición. Esta fase la cambia por
medidas. Todas se repiten con `TESTS/fase7/medir.sh`.

## 2. Entorno de las medidas

- Ubuntu 24.04 en contenedor, FPC 3.2.2.
- **SDL 3.4.4** compilada desde fuente solo con el controlador Wayland
  (`-DSDL_X11=OFF`): SDL3 **no está** en los repositorios de Ubuntu 24.04, lo
  que confirma el riesgo R2 tal como estaba escrito.
- Enlaces `SDL3-for-Pascal` v0.6 vendorizados en `VENDOR/sdl3/` (T7.1).
- Compositor: `weston --backend=headless`, con `DISPLAY` **sin definir**
  (`TESTS/fase7/con-weston.sh`), de modo que nada puede pasar por X11/XWayland
  sin que se note.
- Referencia X11: los mismos programas bajo `xvfb-run`.

Límite conocido: weston sin pantalla no es KWin ni Mutter. Decoraciones,
HiDPI, foco y teclado real no se han medido aquí; son de las fases 9 y 10 y no
dependen de la vía elegida.

## 3. Medidas

### 3.1 T7.2 — la cadena FPC → enlaces → SDL3 → Wayland

Funciona. Ventana con el controlador forzado por *hint*, textura XRGB 640×480
en *streaming* con vecino más próximo, 120 cuadros en ~0,4 s, y **0 píxeles
distintos** al releer el renderizador, tanto con OpenGL como con el
renderizador por software. Sin compositor, `SDL_Init` falla con
`wayland not available` en lugar de caer a X11.

Dos hallazgos que valen para cualquiera de las dos vías:

1. **Los enlaces arrastraban `libX11`.** `SDL3.pas` hacía `uses X, XLib` sin
   usar ningún tipo de esas unidades, y `XLib` trae `{$LINKLIB X11}`. Corregido
   y marcado en `VENDOR/sdl3/` (commit `928ac44`). Tras el cambio el binario
   necesita solo `libSDL3.so.0`, `libm` y `libc`.
2. **Excepciones de coma flotante.** La RTL de FPC las desenmascara y Mesa
   muere con *runtime error 207* en `SDL_CreateRenderer`. Hay que llamar a
   `SetExceptionMask` antes de inicializar SDL. La máscara es estado del hilo:
   ver el riesgo R11.

### 3.2 T7.3 — vía B

El prototipo no se quedó en esqueleto: es una consola que funciona.

| Pregunta de T7.3 | Respuesta medida |
|---|---|
| ¿Cuántos métodos de `IPTCConsole` hacen falta de verdad? | `ptcwrapper` llama a **12**: `Open`, `Close`, `Width`, `Height`, `Format`, `Option`, `Palette`, `Update`, `NextEvent`, `MoveMouseTo`, `Modes` y, a través de `Surface.Copy(Console)`, `Load`. El resto de los 47 que redefine la consola son de una línea o vacíos (OpenGL, `Save`, `Flush`, `Finish`…) |
| ¿Hay que tocar `ptcwrapper`? | **No.** `ptcwrapper.pp` y `ptcgraph.pp` compilan sin cambiar una línea. Además `ptcwrapper` ya está vendorizado desde la Fase 5 (D-18), así que T8B.1 queda casi vacía |
| ¿Cómo encaja en `TPTCConsoleFactory`? | Un define (`PTC_SDL3`), una fila en `ConsoleTypes` y tres bloques condicionales en `ptc.pp`. Sin el define, `ptc.pp` es la consola X11 de siempre |
| Hilos | Todo acceso a la consola ocurre en el hilo de `TPTCWrapperThread`: es justo lo que SDL exige (vídeo y eventos en un mismo hilo) |

Tamaño: **536 líneas** (`sdlconsoled.inc` + `sdlconsolei.inc`), incluido un
mapa de teclas parcial.

Equivalencia visual, con `TESTS/x11/scene_test.lpr -dDIRECT` (líneas con
estilo y XOR, formas, texto bitmap y `.CHR`, `GetImage`/`PutImage`, paleta),
el mismo fuente enlazado contra la consola SDL3 bajo Wayland y contra la X11
bajo Xvfb:

| Comparación | Resultado |
|---|---|
| 10 ficheros de volcado (`.ppm` + `.pal`) Wayland contra X11 | **10 de 10 idénticos byte a byte** |
| `GetPixel`, `GetViewSettings`, `GetRGBPalette` | idénticos |
| Cuadro de 32 bits que la consola SDL3 **presentó** contra el volcado de cada escena | **5 de 5 idénticos**, 0 píxeles |
| Bibliotecas del binario | `libSDL3.so.0`, `libc`, `libm` — sin `libX11` |

Nota de método: la primera medida de «presentado contra volcado» dio 39 905
píxeles distintos. No era un fallo de la consola: el hilo de `ptc` presenta
cada 10 ms, `scene_test` dibuja sus cinco escenas en menos, y el último cuadro
presentado era la pantalla ya borrada. Con `VPA_SCENE_PAUSE_MS=200` y
`presentado.py` (que busca, para cada volcado, un cuadro presentado idéntico)
la medida es la de la tabla.

Regalo no previsto: `SDL_SetRenderLogicalPresentation` +
`SDL_ConvertEventToRenderCoordinates` dan escalado, centrado y ratón en
coordenadas de superficie sin código propio. Eso adelgaza la Fase 10.

Lo que el prototipo **no** resuelve y pasa a las fases 8 y 9: mapa de teclas
completo con el carácter Unicode salido de `SDL_EVENT_TEXT_INPUT` (D-09),
ocultar el cursor, `Suspend`/`Resume`, y `SetMousePos` (riesgo R12).

### 3.3 T7.4 — vía A

Una sola primitiva, `Line` con `SetLineStyle` y `SetWriteMode(XORPut)`, sobre
un guion de abanico de 48 ángulos, cinco estilos × dos grosores en ocho
direcciones y dos sentidos, XOR sobre líneas previas y un viewport con recorte.
Comparado con `ptcgraph` píxel a píxel:

| Bloque del guion | Intento 1 | Intento 2 |
|---|---:|---:|
| Abanico sólido fino | 0 | 0 |
| Estilos × grosor | 2 634 | 0 |
| XOR | 52 | 0 |
| Viewport / recorte | 7 368 | 0 |
| **Total** (de 307 200) | **10 054** | **0** |

- **Intento 1** (`viaa_bgi_intento1.pas`): escrito con la semántica documentada
  de BGI, sin mirar `VENDOR/graph.inc`. Bresenham coincide a la primera; todo
  lo demás, no.
- **Intento 2** (`viaa_bgi.pas`): tras leer `graph.inc` y `clip.inc`. Lo que
  hubo que copiar no está en ningún manual de BGI: `ptcgraph` recorta los
  **extremos** con Cohen-Sutherland (división entera truncada) y reanuda
  Bresenham **y el patrón** desde el extremo recortado; en horizontales y
  verticales con patrón la fase sale de la coordenada **absoluta** de pantalla
  tras ordenar los extremos; el grosor se recorta por píxel.

Lectura honesta: la vía A **converge**, y en una iteración, pero solo
transcribiendo `graph.inc` manía a manía. Es decir, su coste real no es
«reimplementar BGI», es «reescribir a mano el código que la vía B reutiliza
tal cual», para unas veinte primitivas más el rasterizador de `.CHR`
(`graph.inc` 2291 líneas, `gtext.inc` 885, `fills.inc` 612, `palette.inc` 382,
`clip.inc` 141), validando cada una con su propio guion.

## 4. Decisión

**Vía B.**

1. La equivalencia visual deja de ser un objetivo y pasa a ser una propiedad:
   0 píxeles de diferencia medidos, y por construcción, porque las dos rutas
   ejecutan el mismo código de trazado.
2. El coste es de otro orden: ~540 líneas ya escritas y funcionando contra
   varios miles por escribir y validar.
3. Las dos dudas que frenaban la B en la sección 4.2 están resueltas: no hay
   que tocar `ptcwrapper`, y el enganche en PTCPas son un define y una fila.
4. La vía A no aporta hoy nada que la B no dé. Su ventaja (independencia de
   PTCPas) es real pero no es de este proyecto; sigue disponible como
   evolución futura y T7.4 deja demostrado que es viable si algún día hace
   falta.

Coste aceptado: seguimos atados a PTCPas (riesgo R4), ahora con una consola
propia dentro de `VENDOR/ptc/` que río arriba no existe.

## 5. Consecuencias para las fases siguientes

- **Fase 8**: se ejecuta T8B.*. La consola del prototipo es el punto de
  partida de T8B.2–T8B.8, no código a tirar; se revisa y se completa.
  T8B.1 se reduce a comprobar avisos de licencia. T8A.* quedan `[-]`.
- **T8B.9**: el plugin X11 habla con la ventana por Xlib
  (`vpagraph_x11_window.pas`). El Wayland necesita el equivalente sobre SDL:
  hay que exponer `PSDL_Window` desde la consola como se hizo con
  `X11WindowID` (D-18), o resolver foco/pantalla completa/cursor dentro de la
  consola vía `Option`. Se decide al empezar la Fase 8.
- **Fase 9**: el grueso es el mapa de teclas y `SetMousePos` (R12).
- **Fase 10**: escalado, letterbox y coordenadas de ratón ya los da SDL.
- **Fase 12 / R2**: confirmado que hay que empaquetar `libSDL3.so.0`
  (T12.3b); en Ubuntu 24.04 no hay otra forma razonable de tenerla.
- La versión de SDL se comprueba al abrir la consola (`SDL_GetVersion` contra
  `SDL_VERSION` de los enlaces), como pedía R10. Ya está en el prototipo.
