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
| Fecha | 2026-09-13 |

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
```

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
  (38,22)-(64,69). Es esperable, no un fallo del backend.
- **E10** dependía del editor instalado (`Edit file with 'nano'` frente a
  `'no editor found'`); el guion fija `VISUAL=/usr/bin/nano` y ya no depende.

Ninguna escena cae en un bucle de `ArrowBlink`, así que `TESTS/excepciones.txt`
está vacío y la comparación es exacta.

## Cuándo se regeneran

Solo cuando cambia el catálogo (T0.5) o al cerrar la migración (T11.5), y
siempre con el mismo procedimiento de arriba, en la misma máquina o en una con
el `RESOURCE.PLN` real. Si se regeneran, `SHA256SUMS` cambia y el commit dice
por qué.
