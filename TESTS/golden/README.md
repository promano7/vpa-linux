# Imágenes doradas de VPA-Linux (T0.6 de WAYLAND.md)

Este directorio contiene las capturas de referencia con las que se comparan
los backends gráficos: un `Enn-0001.ppm` y un `Enn-0001.pal` por escena de
`docs/reference-scenes.md`. Los binarios **no están en el repositorio**
(`.gitignore`; el porqué en `docs/reference-scenes.md`, sección 2.1): lo que se
versiona es este fichero y `SHA256SUMS`, que dejan constancia de con qué se
doró y permiten comprobar que unas doradas regeneradas son las mismas.

## Procedencia

| | |
|---|---|
| Partida | The Robots (raza 9), turno 90, PHost 4.1h; la de `TESTS/fixture/` |
| Binario | `build/VPA` compilado con `make build` desde la rama `feature/wayland`, VPA 3.67.6 con el volcado de T0.4 |
| Compilador | Free Pascal 3.2.2 |
| Máquina | Contenedor de desarrollo (Ubuntu 24.04 x86_64), bajo el `Xvfb` propio del guion, sin gestor de ventanas. Comprobadas idénticas píxel a píxel a las de la máquina de desarrollo (`pc-arch`, Arch Linux x86_64, Cinnamon) en las escenas capturadas allí; ver abajo |
| `RESOURCE.PLN` | El real del juego (el mismo de `~/PLANETS/RESOURCE.PLN` de la máquina de desarrollo); ver abajo por qué importa |
| Guion | `TESTS/capture.sh`, con las condiciones de `docs/reference-scenes.md`, sección 1 |
| Fecha | 2026-09-13 (E01–E20); 2026-09-20 (E21, añadida en T11.4 sin tocar las otras veinte: sus hashes son los del 13) |

## Cómo se hicieron

```bash
VPA_RESOURCE=~/PLANETS/RESOURCE.PLN TESTS/capture.sh /tmp/cap1
VPA_RESOURCE=~/PLANETS/RESOURCE.PLN TESTS/capture.sh /tmp/cap2
python3 TESTS/compare.py /tmp/cap1 /tmp/cap2          # 20 de 20 idénticas
cp /tmp/cap1/E*-0001.ppm /tmp/cap1/E*-0001.pal TESTS/golden/
( cd TESTS/golden && sha256sum E*-0001.ppm E*-0001.pal > SHA256SUMS )
```

(En el contenedor, `VPA_RESOURCE` apunta a una copia del fichero real.)

Dos pasadas y comparación antes de copiar nada: una escena que no sale igual
dos veces seguidas no es dorada, es un problema que hay que entender.

## Cómo se comprueban

```bash
( cd TESTS/golden && sha256sum -c SHA256SUMS )        # ¿son las doradas?
python3 TESTS/compare.py TESTS/golden /tmp/cur        # ¿coincide una captura nueva?
make visual-test                                      # todo: los dos backends, con informe
```

`make visual-test` (`TESTS/visual/run.sh`, Fase 11) hace las dos cosas de
arriba para el plugin X11 y para el Wayland: se niega a comparar si las doradas
no son las de `SHA256SUMS`, captura el catálogo con cada backend y deja en
`build/visual/` el informe (`informe.md`), las capturas y, de cada escena que
no coincida, el mapa de diferencias. El umbral es **cero píxeles** y el guion no
tiene opción para subirlo (T11.3): los dos plugins pintan con el mismo
`ptcgraph` (vía B, D-06), así que no hay diferencia legítima que tolerar.

## Qué depende de la máquina y qué no

Medido el 2026-09-13 comparando capturas de la máquina de desarrollo (Arch,
FPC 3.2.2) con las del contenedor (Ubuntu, FPC 3.2.2), mismo binario compilado
de la misma rama:

- Con el `RESOURCE.PLN` real, **las 14 escenas cuya secuencia no cambió en
  T0.6 son idénticas píxel a píxel entre las dos máquinas**, incluido el
  `2047M free` del panel (`MemAvail` es constante en Free Pascal sobre Linux).
  Las otras seis (E06, E07, E13, E18, E19 y E20) también: una pasada completa
  en la máquina de desarrollo contra estas doradas da **20 de 20 idénticas, 0
  fallos**. Es decir, una diferencia frente a las doradas es del backend, no
  del entorno, y la comparación se puede correr en cualquiera de las dos.
- Con un `RESOURCE.PLN` ficticio (basta para que VPA arranque), **E14 y E16**
  difieren solo en las imágenes de casco: cajas (28,54)-(74,401) y
  (38,22)-(64,69). Es esperable, no un fallo del backend. E21 (2026-09-20)
  también pinta imágenes de casco, así que le pasa lo mismo (no medido).
- **E10** dependía del editor instalado (`Edit file with 'nano'` frente a
  `'no editor found'`); el guion fija `VISUAL=/usr/bin/nano` y ya no depende.

Ninguna escena cae en un bucle de `ArrowBlink`, así que `TESTS/excepciones.txt`
está vacío y la comparación es exacta.

## Cuándo y cómo se regeneran (T11.5)

**La norma: regenerar una dorada es una decisión consciente que se anota,
nunca un paso para que la prueba deje de quejarse.** Una escena que difiere de
su dorada es, mientras no se demuestre otra cosa, un fallo del código. Por eso
`TESTS/visual/run.sh` no tiene modo «actualizar» y ningún objetivo del
`Makefile` escribe en `TESTS/golden/`: dorar se hace a mano, con los pasos de
abajo.

Motivos legítimos, y no hay más:

- **Cambia el catálogo**: escena nueva, o secuencia corregida en
  `docs/reference-scenes.md`. Solo se doran las escenas afectadas.
- **Un cambio deliberado de VPA altera lo que se ve** (un texto, un color, la
  versión si algún día sale en pantalla). Antes de dorar hay que poder decir
  qué píxeles cambian y por qué, y comprobar con el mapa de diferencias
  (`build/visual/diff-*/`) que cambian esos **y solo esos**.
- **Se pierde la copia local** de la partida o de las doradas y hay que
  rehacerla (`docs/reference-scenes.md`, 2.2).

No son motivo: que falle un solo backend (las doradas valen para los dos; si
X11 pasa y Wayland no, el fallo es del plugin), que falle «a veces» (eso es
una escena no determinista: se arregla la secuencia o se le da una caja en
`TESTS/excepciones.txt`, con su porqué) ni una máquina o un compilador nuevos
(está medido que no influyen; si de pronto influyen, hay que entenderlo).

Procedimiento, con `Enn` como la escena o escenas afectadas (sin escenas,
todas):

```bash
make build hlp
VPA_RESOURCE=~/PLANETS/RESOURCE.PLN TESTS/capture.sh /tmp/cap1 Enn
VPA_RESOURCE=~/PLANETS/RESOURCE.PLN TESTS/capture.sh /tmp/cap2 Enn
python3 TESTS/compare.py /tmp/cap1 /tmp/cap2          # idénticas, o no se dora
python3 TESTS/compare.py TESTS/golden /tmp/cap1 --diff-dir /tmp/diff
#   ... mirar /tmp/diff: ¿cambia lo que tenía que cambiar y nada más?
cp /tmp/cap1/Enn-0001.ppm /tmp/cap1/Enn-0001.pal TESTS/golden/
( cd TESTS/golden && sha256sum E*-0001.ppm E*-0001.pal > SHA256SUMS )
git diff TESTS/golden/SHA256SUMS                      # solo las líneas de Enn
make visual-test                                      # los dos backends, contra las nuevas
```

Se dora siempre con el backend **X11** (`VPA_CAPTURE=x11`, el valor por
defecto): es el de referencia, y Wayland es el que se mide contra él. El
`git diff` de `SHA256SUMS` es la comprobación de que no se ha dorado de más:
una línea cambiada que no sea de las escenas afectadas es una regresión que se
estaba a punto de esconder. El commit lleva `SHA256SUMS`, este fichero si
cambia la procedencia, y en el mensaje **qué escenas** se han dorado y **por
qué**; si el motivo es un cambio de VPA, va en el mismo commit que ese cambio
o en el siguiente, citándolo.

Registro de regeneraciones:

| Fecha | Escenas | Motivo |
|---|---|---|
| 2026-09-13 | E01–E20 | Doradas iniciales (T0.6) |
| 2026-09-20 | E21 | Escena nueva (T11.4): simulador de combate con nave y planeta |
