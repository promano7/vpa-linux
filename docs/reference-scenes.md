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
| Salvapantallas | `ScreenSaverTime` alto en el `VPA.INI` de la partida | Que no se dispare en mitad de una espera del guion |
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

`EXAMPLES/` no contiene ninguna partida, solo `VPA.INI` y un guion de
lanzamiento. Las doradas necesitan una partida **versionada en el repositorio**;
si no, nadie puede regenerarlas ni comprobarlas. Se propone `TESTS/fixture/`
(tarea T0.5b de `WAYLAND.md`), con estos requisitos:

- Un solo turno, un solo jugador, con naves, planetas y al menos una base
  propia, minas y algún mensaje: lo justo para que todas las escenas de la
  sección 3 tengan contenido.
- `VPA.INI` propio dentro del directorio, con `ScreenSaverTime` alto,
  `BadVideoOrMouse = No` y el resto de valores de `EXAMPLES/VPA.INI`.
- Sin reloj (`Shift-S C` apagado) y con nombres de planeta visibles
  (`Shift-S P` encendido), guardado ya así en `VPAx.DB`.
- Sin contraseña de jugador (o con `NOPASSWORD`), para que el arranque no pida
  nada.
- Anotar en `TESTS/golden/README.md`: nombre de la partida, número de raza,
  turno, y versión de VPA con la que se generó el `.DB`.

El número de raza (`N` en `./build/VPA N TESTS/fixture`) se fija al elegir la
partida y se escribe en `TESTS/capture.sh`.

---

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

Para cada escena:

1. `rm -rf $TMP/game && cp -r TESTS/fixture $TMP/game`
2. `VPA_SCALE=1 VPA_GRAPH_DUMP=$OUT/E06- ./build/VPA N $TMP/game &`
3. esperar a que exista la ventana (`xdotool search`)
4. `xdotool mousemove --window $WIN 600 300`
5. inyectar la secuencia de la tabla con `xdotool key --window $WIN`, con una
   pausa tras cada tecla
6. volver a aparcar el puntero (salvo E17)
7. `xdotool key --window $WIN ctrl+F12`
8. esperar a que aparezca `$OUT/E06-0001.ppm`, matar el proceso

Las doradas se guardan como `TESTS/golden/Enn-0001.ppm` y `.pal`, con sus
hashes en `TESTS/golden/SHA256SUMS`. La comparación es:

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
