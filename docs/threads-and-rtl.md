# Hilos y dos RTL en el mismo proceso

Tarea T5.9 de `WAYLAND.md`. Lo que se midió, lo que se encontró y las reglas
que salen de ello. Está escrito **antes** de seguir con el resto de la Fase 5,
como pedía la tarea: si esto se entiende mal, lo que aparece después son
cuelgues intermitentes imposibles de depurar.

La situación de partida: `ptcgraph` levanta un hilo (`TPTCWrapperThread`) para
el bucle de eventos X11, y por eso `cthreads` va el primero en el `uses` de
`VPA/VPA.PAS`. Al mudarse `ptcgraph` al `.so`, en el proceso conviven **dos
RTL de Free Pascal**: el del ejecutable y el de la biblioteca, cada uno con su
gestor de memoria, su gestor de hilos, su lista de unidades que inicializar y
finalizar, y su cadena de manejadores de excepciones.

## 1. Cómo se midió

Arnés `TESTS/x11/threads_test.lpr`. Carga el plugin con `dlopen(RTLD_NOW)`
(no con el cargador de `GRAPH/`, que rechaza con razón un plugin al que aún le
faltan las funciones de entrada), pide la interfaz, y hace `Init` → dibujar →
`Present` → `Shutdown` N veces, luego `dlclose`. Se compila dos veces:

| Variante | RTL del arnés | Compilación |
|---|---|---|
| `threads_test` | **sin** `cthreads` | `fpc -MOBJFPC -gl -gh -FiGRAPH …` |
| `threads_test_ct` | **con** `cthreads` | ídem con `-dUSE_CTHREADS` |

El plugin lleva siempre `cthreads` el primero de su `uses`. Ambas variantes
corren bajo `Xvfb`, con `heaptrc` en el arnés (`-gh`), y además imprimen
`IsMultiThread` del RTL del arnés y la máscara `SigCgt` de
`/proc/self/status` (qué señales tienen manejador instalado) antes de
`dlopen`, después, y después de `dlclose`. Los cuelgues se diagnosticaron con
`gdb -p` y `thread apply all bt`.

Resultado final (2026-09-16, contenedor Ubuntu 24.04, FPC 3.2.2,
glibc 2.39): **las dos variantes pasan**, 20 ciclos en 2,7 s, sin fugas en el
arnés, `dlclose` limpio.

## 2. Respuestas a las tres preguntas de T5.9

### (a) ¿Necesita el `.so` su propio `cthreads`?

**Sí, y lo lleva quiera o no.** `ptcwrapper.pp` hace `uses cthreads` en Unix,
así que cualquier biblioteca que envuelva `ptcgraph` arrastra el gestor de
hilos de su propio RTL. `BACKENDS/X11/vpagraph_x11.lpr` lo pone además
explícitamente y el primero, que es la regla de FPC: el gestor tiene que estar
instalado antes de que se inicialice cualquier otra unidad de ese RTL.

### (b) ¿Puede el ejecutable prescindir de `cthreads`?

**Sí.** La variante sin `cthreads` se comporta exactamente igual que la que lo
lleva: mismos ciclos, mismo `dlclose`, mismo `heaptrc`. El hilo de ptc lo
crea y lo espera el RTL del `.so` con su propio gestor; el RTL del ejecutable
ni se entera (`IsMultiThread` sigue en `FALSE` durante toda la ejecución en
ambas variantes).

Eso responde a T6.9: cuando `ptcgraph` salga de `VPA.PAS`, `cthreads` puede
salir con él. **Pero no se quita en la Fase 5**: mientras el ejecutable enlace
`ptcgraph` estático (hasta T6.8) lo sigue necesitando, y la regla 5 manda.

### (c) ¿Cómo se comporta el gestor de hilos con dos RTL?

Cada RTL gestiona **solo** los hilos que crea él. No se pisan: el
`IsMultiThread` del arnés no cambia cuando el plugin crea o destruye su hilo.
Lo que sí comparten los dos RTL es el **proceso**: el cargador dinámico y su
cerrojo, la tabla de señales y `libc`. Ahí es donde aparecieron los problemas,
y los tres son de la misma familia: cosas que en un ejecutable ocurren al
arrancar o al salir, y que en una biblioteca ocurren dentro de `dlopen` o de
`dlclose`.

## 3. Lo que se encontró

### 3.1 Interbloqueo en `dlclose` (el grave)

`ptcgraph` original crea el hilo de ptc en su `initialization` y lo destruye
(`Terminate` + `WaitFor` + `Free`) en su `finalization`. En un ejecutable eso
es al arrancar y al salir. En un `.so`, la `finalization` corre **dentro de
`dlclose`**, que tiene cogido el cerrojo del cargador dinámico
(`_rtld_global`). El hilo de ptc, al terminar, hace `pthread_exit`, y glibc
carga en ese momento `libgcc_s.so.1` con `dlopen` para poder desenrollar la
pila del hilo… y espera ese mismo cerrojo. Interbloqueo determinista, no
intermitente:

```
Thread 2 (hilo de ptc):
  futex_wait ... _rtld_global+2568
  _dl_open ("libgcc_s.so.1")
  __libc_dlopen_mode
  __GI___libc_unwind_link_get
  __GI___pthread_exit
  CTHREADS_$$_THREADMAIN                       <- libvpagraph-x11.so
Thread 1 (arnés):
  __pthread_clockjoin_ex
  CTHREADS_$$_CWAITFORTHREADTERMINATE          <- libvpagraph-x11.so
  (finalization de ptcgraph, dentro de dlclose)
```

**Regla:** en una biblioteca, **ningún hilo puede morir dentro de `dlclose`**,
y para eso lo más sencillo es que no haya ningún hilo vivo cuando se llama.
Arreglo (cambio 6 de `VENDOR/ptcgraph.pp`, condicionado a `IsLibrary` para
que el ejecutable no cambie):

- la `initialization` **no** crea el hilo;
- `ptc_InternalOpen` (el camino de `InitGraph`) lo crea si no existe, **antes**
  de la primera llamada a `PTCWrapperObject.Option`;
- `CloseGraph` lo termina, lo espera y lo libera;
- la `finalization` es tolerante a `nil`.

Consecuencia para el plugin: el hilo de ptc vive **exactamente** entre `Init`
y `Shutdown`, que es lo que la ABI dice de todos los recursos del backend.

### 3.2 Enumeración de modos en `initialization` (el que explica `/?`)

`QueryAdapterInfo`, que corre en la `initialization` de `ptcgraph`, pedía al
hilo de ptc la lista de modos de pantalla completa del servidor X
(`PTCWrapperObject.Modes`). Sin hilo (3.1) eso era un `nil`, y con hilo era
una conexión X en `dlopen`. Esa consulta es **la** razón de que hoy el
ejecutable necesite sesión gráfica hasta para `/?`.

La lista solo condiciona el doblado de 320×200 en pantalla completa, el modo
Hércules y los modos de 800×600 en adelante; el 640×480 que usa VPA se
registra siempre. En biblioteca, sin hilo, se deja vacía (y `SortModes` no se
llama con una lista vacía: indexa `[0]` y revienta). **Ventaja añadida:
`dlopen` del plugin ya no necesita una sesión gráfica**, que es lo que
`--graph-info` y la selección `auto` de la Fase 6 necesitan.

### 3.3 Señales: el RTL del `.so` no instala manejadores

La máscara `SigCgt` no cambia al hacer `dlopen`: el RTL de una biblioteca FPC
(`IsLibrary`) **no** instala sus manejadores de `SIGSEGV`/`SIGILL`/`SIGBUS`/
`SIGFPE`. Los únicos manejadores del proceso son los del ejecutable. (La
máscara sí gana un bit al crearse el primer hilo, y no lo pierde: es la señal
interna de glibc para la cancelación de hilos, `SIGCANCEL`, no nada de FPC.)

Consecuencia importante para el diseño de los adaptadores: una **excepción
hardware** dentro del plugin (acceso inválido, división por cero…) la captura
el manejador del **ejecutable**, que la convierte en una excepción de **su**
RTL y desenrolla la pila hasta el `try` más cercano **del ejecutable**. El
`try..except` del adaptador, que vive en la cadena de excepciones del RTL del
`.so`, **no la ve**. Se comprobó de las dos formas: los accesos a `nil` de
3.1 y 3.2 aparecieron como `EAccessViolation` sin manejar en el arnés,
señalando la línea del arnés que llamó al plugin.

Por tanto, los `try..except` de `vpagraph_x11_impl.pas` capturan **solo las
excepciones software**: las que lanza el propio RTL del `.so` o el código del
plugin (`EInOutError`, `ERangeError` con las comprobaciones activadas,
`TPTCError`, `Exception.Create`…). Eso es lo que la regla 5 de la ABI puede
garantizar; una excepción hardware es un defecto del plugin y se ve como lo
que es, un fallo del proceso, igual que hoy.

### 3.4 Excepciones en el hilo de ptc (pendiente: T5.5b)

Sin `DISPLAY`, `dlopen` funciona (gracias a 3.2), pero `Init` **aborta el
proceso** en vez de devolver `VPAG_ERR_VIDEO`: `TX11Console.Open` lanza
`TPTCError('Cannot open X display')` **dentro del hilo de ptc**, el `Execute`
del wrapper solo tiene `try..finally`, y `TPTCError` ni siquiera desciende de
`Exception`. El hilo muere con una excepción sin manejar y el RTL del `.so`
tira el proceso. Hoy el ejecutable hace lo mismo (muere en la
`initialization`), así que no es una regresión, pero la Fase 6 necesita que
`Init` **falle limpio** para poder caer de un backend a otro. Queda como
**T5.5b**: capturar en `TPTCWrapperThread.ProcessRequests` el error de `Open`
y devolvérselo al llamante, y en `ptc_InternalOpen` traducirlo a
`_graphresult`.

## 4. Reglas que se derivan (para todos los plugins, también el de Wayland)

1. **Ningún recurso del proceso se adquiere en `initialization` ni se libera
   en `finalization`** del `.so`: ni hilos, ni conexiones al servidor
   gráfico, ni ventanas. Todo entre `Init` y `Shutdown`. `dlopen` y `dlclose`
   tienen que ser inertes.
2. `cthreads` va el primero en el `.lpr` de cada plugin, aunque una
   dependencia ya lo arrastre.
3. El `try..except` de cada adaptador protege contra excepciones software;
   no hay forma de proteger la frontera contra una excepción hardware, así
   que un puntero nulo en el plugin es un fallo del proceso y hay que tratarlo
   como tal (comprobaciones activadas durante el desarrollo, `plugins.cfg`).
4. Un error que ocurra en **otro hilo** del plugin no llega al adaptador por
   sí solo: hay que recogerlo explícitamente y devolverlo por la interfaz
   (T5.5b).
5. Cada RTL libera lo que reserva. Ya era la regla 9 de la ABI; aquí se ve
   por qué es física y no estilística: son dos gestores de memoria distintos.

## 5. Cómo repetirlo

```bash
make x11-plugin
fpc -MOBJFPC -gl -gh -FiGRAPH -FUbuild/x11 -obuild/x11/threads_test    TESTS/x11/threads_test.lpr
fpc -MOBJFPC -gl -gh -FiGRAPH -FUbuild/x11 -obuild/x11/threads_test_ct -dUSE_CTHREADS TESTS/x11/threads_test.lpr
xvfb-run -a ./build/x11/threads_test    $PWD/build/plugins/libvpagraph-x11.so 20
xvfb-run -a ./build/x11/threads_test_ct $PWD/build/plugins/libvpagraph-x11.so 20
```

Salida 0 y `threads_test: PASS` en las dos. Con `HEAPTRC=log=fichero` se
obtiene el informe de `heaptrc` (`0 unfreed memory blocks`). El objetivo
`threads-test` del `Makefile` hace todo esto.
