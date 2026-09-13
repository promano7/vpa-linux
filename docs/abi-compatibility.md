# Reglas de compatibilidad de la ABI de VPAGraph

Tarea T2.14 de `WAYLAND.md`. Define qué se puede cambiar en
`GRAPH/vpagraph_abi.inc` sin romper plugins ya construidos, qué obliga a subir
`VPAGRAPH_ABI_VERSION` y cómo se comporta cada combinación de ejecutable y
plugin descompasados.

La razón de tener estas reglas escritas: el ejecutable y el `.so` se compilan
por separado y el usuario puede acabar con una pareja que no case —una
distribución que empaqueta el plugin aparte, una actualización a medias, un
plugin de terceros—. Sin negociación, eso es un salto a una dirección
arbitraria en mitad de una partida. Con ella, es un mensaje de error.

## 1. El mecanismo, en una frase

El ejecutable reserva `TVPAGraphInterface`, le pasa al plugin su tamaño y la
versión que sabe hablar, y el plugin decide si puede servirla; si acepta,
rellena la estructura sin pasarse del tamaño recibido.

```
nucleo                                   plugin (.so)
  dlopen(ruta)
  dlsym('VPAGraph_GetInterface')  ---->  el simbolo existe o no
  GetInterface(1, SizeOf(iface), @iface)
                                  <----  VPAG_OK / ABI_MISMATCH / STRUCT_SIZE
  comprobar ABIVersion, StructSize
  comprobar punteros obligatorios
  iface.Init(@params)
```

## 2. Qué se puede cambiar sin subir la versión

Solo lo que no altera nada de lo que ya existe:

- **Añadir un campo AL FINAL** de `TVPAGraphInterface`, consumiendo una casilla
  de `Reserved`. El tamaño total no cambia, así que ni siquiera cambia
  `StructSize`.
- **Añadir un campo al final** de `TVPAGraphEvent` o `TVPAGraphInitParams`
  usando su `Reserved`, con el mismo efecto.
- **Añadir constantes nuevas** (un código de error, un tipo de evento, un
  código de tecla) siempre que no cambien el valor de ninguna existente.
- **Cambiar la implementación de un plugin** sin tocar este fichero.

En todos estos casos, un plugin construido contra la versión anterior sigue
funcionando: los campos nuevos le llegan a cero y el núcleo ya comprueba que un
puntero no sea nulo antes de usarlo.

## 3. Qué obliga a subir la versión

Cualquier cosa que cambie el significado o la posición de algo que ya existía:

- Reordenar, insertar en medio o borrar un campo de cualquier estructura.
- Cambiar el tipo o el tamaño de un campo.
- Cambiar la firma de una función: número de parámetros, tipos, orden,
  convención de llamada.
- Cambiar la semántica sin cambiar la firma. Es el caso traicionero: si
  mañana `GetMouseState` devolviera coordenadas de ventana en vez de
  superficie, el compilador no diría nada y el ratón se iría a otro sitio.
  Cuenta como cambio de ABI igual que si cambiara la firma.
- Cambiar el valor de una constante que cruza la frontera (`VPAG_PUT_XOR`,
  un `VPAGK_*`, un código de error).
- Cambiar el contrato de memoria de las imágenes o de la paleta.

Al subir la versión se actualiza `VPAGRAPH_ABI_VERSION`, se anota aquí qué
cambió y por qué, y los plugins hay que reconstruirlos.

## 4. Cómo se comporta cada pareja descompasada

| Situación | Qué pasa | Resultado |
|---|---|---|
| Plugin **más nuevo**, núcleo viejo | El núcleo pide la versión N, el plugin habla N+1 | El plugin devuelve `VPAG_ERR_ABI_MISMATCH`. El núcleo lo rechaza y prueba el siguiente backend |
| Plugin **más viejo**, núcleo nuevo | El núcleo pide N+1, el plugin solo sabe N | Igual: `VPAG_ERR_ABI_MISMATCH` |
| Misma versión, plugin compilado con un `.inc` que tenía la estructura **más grande** | `InterfaceSize` que recibe es menor que su `SizeOf` | El plugin devuelve `VPAG_ERR_STRUCT_SIZE` y no escribe nada. Esto es lo que impide que escriba más allá de lo que el núcleo reservó |
| Misma versión, estructura **más pequeña** al otro lado | El plugin rellena menos de lo que el núcleo espera | El núcleo ve `StructSize` menor que el suyo; trata como no implementado todo lo que quede por encima de ese tamaño |
| Plugin sin el símbolo de entrada | `dlsym` devuelve nil | El núcleo lo rechaza al cargar (`TESTS/abi/bad_nosymbol.lpr`) |
| Plugin que miente en `StructSize` | Anuncia un tamaño incoherente | El núcleo lo rechaza sin leer la tabla (`bad_structsize.lpr`) |
| Plugin con funciones obligatorias a nil | Pasa la negociación pero la tabla está incompleta | El núcleo comprueba puntero a puntero y lo rechaza (`bad_nullprocs.lpr`) |

Regla general de las dos partes: **rechazar limpio y explicar, nunca seguir
adelante con una duda.** Un backend que no carga deja jugar en el otro; un
backend que carga a medias corrompe una partida.

## 5. Funciones obligatorias y opcionales

El núcleo comprueba que **no sean nulos** los punteros sin los cuales VPA no
puede jugar: `Init`, `Shutdown`, `Present`, `ClearDevice`, `SetViewPort`,
`GetViewSettings`, `SetColor`, `GetColor`, `SetLineStyle`, `SetFillStyle`,
`SetWriteMode`, `PutPixel`, `GetPixel`, `Line`, `LineTo`, `LineRel`, `MoveTo`,
`Rectangle`, `Bar`, `Circle`, `Ellipse`, `ImageSize`, `GetImage`, `PutImage`,
`SetRGBPalette`, `GetRGBPalette`, `OutTextXY`, `SetTextStyle`,
`SetTextJustify`, `InstallUserFont`, `PollEvent`, `GetModifiers`,
`GetMouseState`, `SetMousePos`, `ShowMouse`.

Pueden ser nulos, y el núcleo se las arregla sin ellos:

- `GetLastError` — sin él, los errores se reportan solo por código.
- `GraphResult` — el núcleo recuerda el último código que le devolvieron.
- `Suspend` / `Resume` — un backend que no sepa suspenderse deja la ventana
  abierta mientras corre el programa externo; es peor, pero se juega.
- `SetFullscreen`, `GetScreenSize`, `GetWindowSize` — sin ellos no hay
  pantalla completa y la escala cae al 100 %.
- `SetRGBPaletteBlock` — el núcleo llama a `SetRGBPalette` en bucle.
- `DumpFrame` — solo afecta a las pruebas de la Fase 11.

Un plugin que no implemente algo opcional puede dejar el puntero a nil o
devolver `VPAG_ERR_UNSUPPORTED`; las dos cosas valen y significan lo mismo.

## 6. Plugins de prueba

En `TESTS/abi/` hay cinco bibliotecas que existen justo para ejercitar todo lo
anterior sin un servidor gráfico delante. Se construyen así:

```
fpc -MOBJFPC -Cg -FiGRAPH -o<destino>/<nombre>.so TESTS/abi/<nombre>.lpr
```

| Fichero | Qué prueba |
|---|---|
| `stub_backend.lpr` | El camino bueno: interfaz completa y válida que no dibuja nada |
| `bad_nosymbol.lpr` | Biblioteca sin el símbolo de entrada |
| `bad_abiversion.lpr` | Se anuncia como ABI 99 |
| `bad_structsize.lpr` | `StructSize` incoherente |
| `bad_nullprocs.lpr` | Cabecera correcta, funciones obligatorias a nil |

Y dos unidades que comprueban el propio `.inc`:

| Fichero | Qué prueba |
|---|---|
| `abi_tp.pas` | Que el `.inc` se puede consumir desde modo Turbo Pascal (como todo VPA) |
| `abi_objfpc.pas` | Que también desde `objfpc` (como los plugins), y los tamaños de los tipos |

Las dos llevan las **mismas** aserciones de tamaño de `TVPAGraphEvent` (72),
`TVPAGraphInitParams` (32) y `TVPAGraphInterface` (440). No es redundancia: los
dos modos de compilación podrían empaquetar los registros de forma distinta, y
entonces la ABI estaría rota aunque ambos lados compilaran. Comprobado en la
Fase 2: los tamaños y los desplazamientos coinciden en los dos modos.

## 7. Registro de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| 1 | 2026-09-13 | Primera versión. 44 funciones, `TVPAGraphInitParams`, `TVPAGraphEvent`, `TVPAGraphInterface` (440 bytes) |
