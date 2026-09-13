# Catálogo de escenas de referencia (T0.5 de WAYLAND.md)

Lista corta y reproducible de pantallas de VPA que ejercitan lo que importa
para la comparación entre backends. Cada escena tiene un identificador estable
(`E01`, `E02`…), la secuencia exacta de teclas que la produce y el motivo por
el que está en la lista. Las imágenes doradas de `TESTS/golden/` se capturan
siguiendo este documento (tarea T0.6) y se regeneran siguiendo este documento
(tarea T11.5). Si una escena cambia de secuencia, cambia aquí primero.

Documento interno del port, solo en español, igual que `WAYLAND.md`.

---

## 1. Condiciones de captura

Las capturas solo son comparables si se toman siempre en las mismas
condiciones. Estas son las que ha fijado la inspección del código en 3.67.6:

| Condición | Valor | Motivo |
|-----------|-------|--------|
| Escala | `VPA_SCALE=1` | La ventana mide 640×480 y coincide 1:1 con la superficie; así las coordenadas de `xdotool` son coordenadas de superficie sin conversión |
| Servidor | `Xvfb`, sin gestor de ventanas | Sin gestor, la ventana aparece en (0,0) y nadie la mueve, la redimensiona ni le roba el foco |
| Puntero | Aparcado en **(600,300)** de la ventana antes de cada captura | La primera línea del panel derecho muestra las coordenadas de mapa bajo el puntero (`1701,2637`) o `2047M free` si el puntero está fuera del mapa. Sin fijar el puntero, dos capturas de la misma escena difieren en esa línea. (600,300) cae dentro del mapa pero fuera del panel |
| Partida | **Copia limpia** de la partida de referencia para cada escena | `VPAx.DB` guarda la posición del mapa, el zoom, las capas visibles (`Shift-S`) y el reloj (`showC`); cualquier ejecución anterior que haya guardado cambia el arranque siguiente |
| Reloj | Desactivado en la partida de referencia (`showC = 0`) | Un reloj en el mapa invalida todas las escenas de mapa |
| Salvapantallas | `ScreenSaverTime = 0` en el `VPA.INI` del directorio de ejecución (y en el de la partida, si lo tuviera) | Que no se dispare en mitad de una espera del guion. Con `= 1`, que es lo que trae `VPA/VPA.INI`, una escena de varias teclas a un segundo por tecla lo alcanza, y `SCRSAVER` repinta encima del volcado |
| Directorio de ejecución | Directorio propio montado por el guion, con `VPA.HLP`, `RESOURCE.PLN`, `DISTTABL.DAT`, `VPA.MSG` y `LITT_VPA.CHR` | VPA abre esos ficheros por el nombre pelado, o sea relativos al directorio actual, no a `addir` (`OpenFile`/`OpenData` en `VPA/VPADATA.PAS`). Los tres primeros son obligatorios y VPA aborta antes de abrir la ventana si faltan. Con un directorio propio la captura no depende de desde dónde se lance el guion |
| Configuración | `VPA.INI` del repositorio (`VPA/VPA.INI`) en el directorio de ejecución | La configuración con la que se toman las doradas queda fijada por el repositorio, no por el `~/PLANETS` de quien capture |
| Teclas aleatorias | Nunca `R`, `Ctrl-R`, `Alt-R` en una secuencia | Códigos amistosos aleatorios: `Randomize` en `VPA/VPADATA.PAS` |
| Salida | Matar el proceso tras la captura | No hace falta guardar: la copia se descarta. Evita el diálogo de `Ctrl-Alt-X` y cualquier escritura en disco |
| Cursor del ratón | Sin efecto | Lo dibuja el servidor X (`ptcmouse` → `PTCWrapperObject.Option('show cursor')`), no VPA; nunca aparece en el volcado |

`MemAvail` (el `2047M free`) es constante en Free Pascal sobre Linux dentro de
una misma máquina, pero no está garantizado entre máquinas. Si una dorada
capturada en otra máquina difiere solo en esa esquina, es esto.

### 1.1 Un proceso por escena

Cada escena se captura en un proceso nuevo de VPA sobre una copia nueva de la
partida. Es más lento que encadenar escenas en un solo proceso, pero elimina
dos fuentes de error: el estado que una pantalla deja en la siguiente (por
ejemplo, `Ctrl-O` reescribe `VPA.INI` al salir) y la numeración de los
volcados, que es por proceso. Con un proceso por escena, cada una produce
exactamente `<prefijo>0001.ppm` y `<prefijo>0001.pal`.

### 1.2 Tiempos de espera

VPA redibuja de forma síncrona, pero `xdotool` inyecta eventos por el servidor
X y `ptcgraph` los recoge en su hilo de eventos. Entre tecla y tecla hay que
esperar lo suficiente para que la pantalla esté terminada antes de `Ctrl-F12`.
Los valores del guion (`TESTS/capture.sh`) son generosos; si una captura sale
a medio dibujar, es que la espera es corta, no que el backend falle.

---

## 2. La partida de referencia

Las doradas se capturan siempre sobre la misma partida, que vive en
`TESTS/fixture/`. La partida es **The Robots, turno 90**, raza **9**; se lanza
con `./build/VPA 9 TESTS/fixture` y ese número está fijado en
`TESTS/capture.sh`, en la variable `RACE`.

### 2.1 No está en el repositorio, y es deliberado

`TESTS/fixture/` y `TESTS/golden/` están en `.gitignore`. Solo existen en la
copia local de quien captura. Los motivos:

- Los ficheros de datos del juego (`HULLSPEC.DAT`, `TRUEHULL.DAT`,
  `XYPLAN.DAT`, `PLANET.NM`…) son de Tim Wisseman, y el repositorio es público
  y MPL-2.0.
- Es una partida real por correo: los mensajes los han escrito otras personas,
  que no han dado permiso para publicarlos.
- `FIZZ.BIN` contiene la clave de registro del jugador. Con la partida fuera
  del repositorio, el riesgo no hay que gestionarlo: no existe.
- Las doradas son decenas de MB de binarios que solo crecerían, y un commit no
  se deshace: lo que entra en el historial se queda.

Del directorio de doradas sí se versionan dos ficheros de texto,
`TESTS/golden/README.md` y `TESTS/golden/SHA256SUMS`, reincluidos
explícitamente en `.gitignore`. No pesan nada y dejan constancia en el
repositorio de qué escenas se doraron, sobre qué partida, con qué versión de
FPC y con qué hashes, aunque las imágenes vivan solo en un disco.

### 2.2 Lo que eso cuesta, y por qué se acepta

Nadie ajeno puede verificar ni regenerar las doradas. Es una pérdida real, pero
el público de estas imágenes son quienes hacen la migración: son una red de
regresión de obra, no un artefacto publicable. Las pruebas que hacen los
colaboradores son partidas reales, no comparaciones de píxeles.

La consecuencia práctica: **la copia local es la única que hay**. Conviene
guardarla fuera del árbol de trabajo, porque un `git clean -xfd` se la lleva
por delante sin preguntar. Si aun así se pierde, no es una catástrofe: se
prepara una partida nueva siguiendo 2.3, se vuelven a capturar las veinte
escenas y ese juego pasa a ser la referencia, con el procedimiento de
regeneración de T11.5. Lo que se pierde es la continuidad con lo capturado
antes, no la capacidad de seguir trabajando.

### 2.3 Qué tiene que cumplir la partida

Para poder rehacerla si hace falta, y para que las escenas de la sección 3
tengan algo que dibujar:

- Un turno desempaquetado, con naves, planetas y al menos una base propia con
  campos de minas, y mensajes en el buzón.
- Sin contraseña de jugador: el arranque no debe pedir nada.
- No hace falta `VPA.INI` propio: la configuración sale del directorio de
  ejecución que monta `TESTS/capture.sh` a partir de `VPA/VPA.INI`. Si la
  partida trae uno, el guion le pone `ScreenSaverTime = 0`, porque el de la
  partida se lee después del del directorio actual y lo pisa
  (`ReadConfig1` en `VPA/CONFIG.PAS`).
- Reloj apagado y nombres de planeta encendidos (`Shift-S C` / `Shift-S P`),
  guardado ya así en `VPA9.DB`, porque de ahí sale la vista inicial de E01.
- `FIZZ.BIN` no hace falta: VPA lo recrea al arrancar
  (`VPA/VPAINIT.PAS:1529`) y solo lo usa al desempaquetar un RST y al salir.
  Ninguna pantalla muestra información de registro.
- Anotar en `TESTS/golden/README.md` la partida, la raza, el turno y la
  versión de VPA con la que se generó el `.DB`.

### 2.4 El directorio no se juega in situ

VPA recrea `FIZZ.BIN` y reescribe la vista en `VPA9.DB` al salir, así que
jugar directamente en `TESTS/fixture/` cambia el punto de partida de la
siguiente captura. `TESTS/capture.sh` copia a un temporal antes de cada escena
y descarta la copia; cualquier prueba manual debe hacer lo mismo:

```bash
cp -r TESTS/fixture /tmp/game && VPA_SCALE=1 ./build/VPA 9 /tmp/game
```

Esa prueba manual hay que lanzarla desde un directorio donde estén `VPA.HLP`,
`RESOURCE.PLN` y `DISTTABL.DAT`, o VPA aborta antes de abrir la ventana. El
guion no tiene ese problema: se monta su propio directorio de ejecución (ver
sección 1).

## 3. Escenas

Convenciones de la columna de teclas: notación de `xdotool key`
(`ctrl+F10`, `Tab`, `Return`, `space`, `Escape`). El puntero se aparca en
(600,300) justo antes de la captura, y la captura es siempre `ctrl+F12`, que
no se repite en cada fila. Todas las secuencias parten del **mapa estelar
recién arrancado**, con la partida limpia.

La columna «Ejercita» dice qué parte de la frontera gráfica pone a prueba la
escena, para que al fallar una comparación se sepa por dónde empezar a mirar.

| Id | Escena | Teclas | Ejercita |
|----|--------|--------|----------|
| E01 | Mapa estelar, vista inicial | *(ninguna)* | `Circle`, `Line`, `PutPixel`, `LittFont` en etiquetas, paleta base, panel derecho con `DefaultFont` |
| E02 | Mapa con un nivel de zoom | `Tab` | Escalado de coordenadas, recorte de círculos en el borde del mapa, etiquetas más densas |
| E03 | Galaxia entera | `ctrl+Tab` | Recorte extremo, muchas primitivas pequeñas, `PutPixel` |
| E04 | Ayuda general | `F1` | Página entera de `DefaultFont` en varios colores; `SetTextJustify`; la primera línea subrayada |
| E05 | Ayuda general, continuación | `F1` `F1` | Ídem, distinto contenido; comprueba que dos páginas seguidas no dejan restos |
| E06 | Ficha de nave | `s` | Panel derecho denso, lista de naves con resaltado invertido (barra gris), ayuda contextual a la izquierda |
| E07 | Ficha de planeta | `p` | Tabla de minerales (`Rectangle` + `Line` en rejilla), texto en varios colores, `{62}` entre llaves |
| E08 | Ficha de base | `b` | Ídem, con la lista de campos de minas |
| E09 | Procesador de mensajes | `F3` | Ventana de texto, `Bar` de fondo, cabeceras |
| E10 | Menú de configuración `VPA.INI` | `ctrl+o` | `GetImage`/`PutImage` del fondo (el de la corrupción de heap de 3.67.5), columnas `On_`/`Off_` (el desalineamiento de 3.67.6) |
| E11 | Simulador de combate | `F5` | `PutImage` con buffers construidos a mano (`VPA/TCOMBAT.PAS`), paleta modificada con `SetRGBPalette` |
| E12 | Puntuaciones y gráfico de poder | `F10` | Gráfico con `Line` y `SetLineStyle`; tabla |
| E13 | Estadísticas de recursos | `ctrl+F10` | Tabla `StatColor` (el azul ilegible de 3.67.5); cada color de la serie tiene que ser el mismo |
| E14 | Informe de flota | `ctrl+F11` | `SetViewPort` del panel derecho (el desplazamiento de 32 píxeles de 3.67.5) |
| E15 | Simulador de economía planetaria | `F6` | Formulario con campos editables, `Bar` + `Rectangle` |
| E16 | Astillero (construcción de naves) | `b` `b` | Diálogo de construcción con lista de cascos y precios; se llega desde la ficha de base |
| E17 | Modo distancia (goma elástica) | `Return` `space` *(mover puntero a (300,200))* | `SetWriteMode(XORPut)`: la línea elástica desde el objeto seleccionado hasta el puntero. Es la escena más sensible al modo XOR |
| E18 | Selección de objeto en el mapa | `Return` | Marca de selección (círculo rojo) y panel derecho del objeto más cercano al puntero aparcado |
| E19 | Leyenda del mapa | `l` | Muestrario de todos los símbolos y colores del mapa en una sola pantalla |
| E20 | Créditos | `F1` `c` | Texto en `LittFont` y `DefaultFont` mezclados con distintos tamaños |

### 3.1 Notas por escena

- **E01–E03.** El mapa depende de la posición guardada en `VPAx.DB`; por eso
  la partida de referencia se guarda con la vista que se quiere como E01 y no
  se toca después.
- **E06–E08.** La nave, el planeta y la base que se muestran son «el objeto
  actual» al arrancar, que también viene del `.DB`. No hace falta seleccionar
  ninguno con `F7`/`Shift-F7`: la copia limpia garantiza que sea siempre el
  mismo. **A validar en T0.6:** la ayuda general describe `P,B` en el mapa
  como «select planet or SB under the pointer», así que con el puntero
  aparcado en el vacío puede que no abran la ficha. Si es así, la secuencia
  pasa a ser `Return` (ficha del objeto más cercano al puntero aparcado, la
  misma de E18) seguido de `p` o `b` desde esa ficha, que sí conmutan entre
  pantallas de información («P - switch to planet info screen», «B - switch
  to starbase info screen»), y se corrige aquí y en `TESTS/capture.sh`.
- **E10.** `Ctrl-O` reescribe `VPA.INI` al salir del menú. Como el proceso se
  mata tras la captura y la copia se descarta, no importa; pero es el motivo
  de que esta escena **no** pueda ir seguida de otra en el mismo proceso.
- **E11.** El simulador de combate puede arrancar pidiendo datos. Si en la
  partida elegida abre directamente el visor con la última simulación, la
  captura es esa pantalla; si abre el formulario, es el formulario. Se anota
  cuál de las dos es al capturar (T0.6) y no se cambia después.
- **E16.** `b` desde el mapa lleva a la ficha de base; un segundo `b` desde
  la ficha de base abre el astillero (`B - switch to ship construction
  screen`). Requiere que el objeto actual tenga base; la partida de referencia
  debe cumplirlo.
- **E17.** `Return` selecciona el objeto más cercano al puntero aparcado (el
  mismo de E18); `space` entra en modo distancia; después se mueve el puntero
  con `xdotool mousemove` a (300,200) y se captura **sin volver a aparcarlo**,
  porque la goma elástica termina en el puntero. Es la única escena con el
  puntero en otro sitio, y por eso su línea de coordenadas del panel derecho
  será distinta de las demás: es correcto.
- **E20.** `c` en la pantalla de ayuda general muestra los créditos
  («Credits screen (press C)»).

### 3.2 Escenas descartadas

- **Salvapantallas.** `VPA/SCRSAVER.PAS` elige la imagen y la orientación con
  `Random`, así que dos ejecuciones nunca coinciden. No es comparable píxel a
  píxel y no entra en `TESTS/golden/`. Se comprueba de otra manera: en T6.14 y
  en la Fase 9, que aparece al vencer `ScreenSaverTime` y que cualquier tecla
  lo quita sin dejar restos.
- **Diálogos que piden entrada** (`F7` buscar planeta, `Alt-C` calculadora,
  `N` renombrar): dependen de lo que se teclee y no aportan primitivas que no
  cubran E04–E15. Si en la Fase 11 aparece un fallo en uno de ellos, se añade
  entonces con su secuencia completa.

---

## 4. Cómo se capturan (resumen; el detalle está en `TESTS/capture.sh`)

Una vez, antes de nada: montar el directorio de ejecución (enlaces a
`VPA.HLP`, `RESOURCE.PLN`, `DISTTABL.DAT`, `VPA.MSG`, `LITT_VPA.CHR` y el
`VPA.INI` del repositorio con el salvapantallas apagado), comprobar que los
obligatorios están, arrancar `Xvfb -s 0` y esperar a que **acepte conexiones**,
no un `sleep` a ojo.

Para cada escena:

1. `rm -rf $TMP/game && cp -r TESTS/fixture $TMP/game`
2. `cd $RUN && VPA_SCALE=1 VPA_GRAPH_DUMP=$OUT/E06- $VPA_BIN N $TMP/game &`
3. esperar a que exista la ventana, buscándola por su título, que es la ruta
   exacta del binario (`WindowTitle := ParamStr(0)` en `VENDOR/ptcgraph.pp`);
   si el proceso muere antes, es que ha abortado, y el log lo dice
4. dar el foco a la ventana (`xdotool windowfocus`) y `xdotool mousemove
   --window $WIN 600 300`
5. inyectar la secuencia de la tabla con `xdotool key`, con una pausa tras cada
   tecla
6. volver a aparcar el puntero (salvo E17)
7. `xdotool key ctrl+F12`
8. esperar a que `$OUT/E06-0001.pal` tenga sus 768 bytes —el `.pal` se escribe
   después del `.ppm`, así que es la señal de que el volcado ha terminado— y
   matar el proceso

Las doradas se guardan como `TESTS/golden/Enn-0001.ppm` y `.pal` (fuera del
control de versiones, ver 2.1), con sus hashes en `TESTS/golden/SHA256SUMS` y
la procedencia en `TESTS/golden/README.md`, que sí se versionan. La comparación
es:

```bash
python3 TESTS/compare.py TESTS/golden /tmp/cur
```

---

## 5. Estado de validación

Las secuencias de la sección 3 salen de las pantallas de ayuda de VPA y de la
inspección del código; se validan **una a una** al capturar las doradas
(T0.6). Cuando una escena se haya capturado y comprobado que la secuencia
produce lo que dice la tabla, se marca aquí:

| Id | Validada | Observaciones |
|----|:--------:|---------------|
| E01 | | |
| E02 | | |
| E03 | | |
| E04 | | |
| E05 | | |
| E06 | | |
| E07 | | |
| E08 | | |
| E09 | | |
| E10 | | |
| E11 | | ¿formulario o visor? |
| E12 | | |
| E13 | | |
| E14 | | |
| E15 | | |
| E16 | | requiere base en el objeto actual |
| E17 | | |
| E18 | | |
| E19 | | |
| E20 | | |
