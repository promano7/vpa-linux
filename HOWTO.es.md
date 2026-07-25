# VPA-Linux — Cómo ejecutarlo

> 🌍 This document is also available in English: [`HOWTO.en.md`](HOWTO.en.md).

**VGA Planets Assistant (VPA) 3.67**, compilación nativa para GNU/Linux.

VPA es un cliente/ayudante para el clásico juego de estrategia por correo **VGA
Planets 3**: carga tu turno (`RST`), te permite revisar el mapa estelar, los
planetas, las naves, las bases y los mensajes, y el simulador de combate, y
escribe tus órdenes de vuelta en un fichero de turno (`TRN`). Es un port nativo
fiel a Linux del programa original de DOS — mismo aspecto, mismas teclas.

> Esta es la **guía de usuario final** para el binario ya compilado. Si prefieres
> compilar desde el código fuente, consulta `BUILD.es.md`.

---

## 1. Qué necesitas

- Un sistema **Linux x86 de 64 bits** con sesión gráfica (X11 o Wayland).
- El **binario `VPA`** (incluido en este paquete), más los ficheros de apoyo que
  se distribuyen con él: **`DISTTABL.DAT`** (obligatorio — una tabla de
  distancias que VPA necesita para arrancar), **`VPA.MSG`** (plantillas de
  mensajes), el fichero de ayuda **`VPA.HLP`** y la fuente de mapa
  **`LITT_VPA.CHR`**.
- Un **directorio de partida** de VGA Planets propio: la carpeta con tus ficheros
  de turno (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, `PLAYERx.RST`,
  etc.), donde `x` es tu número de raza. VPA **no** incluye ninguna partida; esos
  ficheros los obtienes de tu host de VGA Planets.

### Librerías en tiempo de ejecución
El binario usa un puñado de librerías X11 estándar que ya están presentes en
prácticamente cualquier escritorio Linux. Si se queja de algún `lib….so` que
falta, instálalas:

- **Arch:** `sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm`
- **Debian/Ubuntu:** `sudo apt install libx11-6 libxext6 libxfixes3 libxi6 libxrandr2 libxxf86vm1`
- **Fedora:** `sudo dnf install libX11 libXext libXfixes libXi libXrandr libXxf86vm`

> **Wayland:** funciona sin nada que configurar, a través de **XWayland**
> (presente en casi todos los escritorios).

---

## 2. Ejecutar VPA

Dale permiso de ejecución al binario una vez, y luego ejecútalo con tu **número
de raza** y tu **directorio de partida**:

```sh
chmod +x VPA          # solo la primera vez
./VPA <raza> [directorio-de-partida]
```

- `<raza>` — tu número de jugador (1–11).
- `[directorio-de-partida]` — la carpeta con tus ficheros de turno. Si se omite,
  se usa el directorio actual.

Ejemplo (jugando la raza 3, partida en `~/PLANETS/mipartida`):
```sh
./VPA 3 ~/PLANETS/mipartida
```

Ejecútalo sin argumentos para ver el banner y confirmar que arranca:
```
$ ./VPA
-= VGA Planets Assistant 3.67  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team =-
Use: VPA race [dir] ...
```

`./VPA /?` lista todas las opciones de línea de comandos (`/B`, `/K`, `/M`, `/O`,
`/P`, `/PW:pwd`, `/R`, `/S`, `/REP:frm,rep`).

### Ficheros de apoyo
Mantén estos ficheros donde ejecutes VPA — en tu directorio de partida o junto al
binario:

- **`DISTTABL.DAT`** — una tabla de distancias precalculada. **Obligatorio:** VPA
  se niega a arrancar (y sale) si falta o está dañado. Distribúyelo tal cual, no
  lo edites.
- **`VPA.MSG`** — las plantillas de mensajes que usa VPA para interpretar y
  formatear los mensajes entrantes del host. Si falta, VPA sigue funcionando pero
  avisa y no puede interpretar los mensajes. Es un fichero de texto plano con
  finales de línea **Unix (LF)** — mantenlo así; una copia en formato DOS (CRLF)
  no se interpretará correctamente en Linux.
- **`VPA.HLP`** — la ayuda integrada. Con él presente, pulsa **F1** dentro de VPA
  para ver la pantalla de ayuda; sin él, F1 simplemente no muestra nada.
- **`LITT_VPA.CHR`** — la pequeña fuente vectorial usada para las etiquetas del
  mapa (nombres de planeta y de nave). Si falta, VPA sigue funcionando pero cae a
  una fuente integrada, así que esas etiquetas no se verán del todo bien.

Solo `DISTTABL.DAT` es estrictamente obligatorio para arrancar; el resto son
opcionales, pero convienen para la experiencia completa y correcta.

---

## 3. Tamaño de ventana y pantalla completa

La pantalla de VPA es de 640×480. Para agrandar la ventana, define la variable
de entorno **`VPA_SCALE`** antes del comando (no distingue mayúsculas de
minúsculas):

```sh
# Pantalla completa:
VPA_SCALE=fullscreen ./VPA 3 ~/PLANETS/mipartida

# La más pequeña, ventana nativa 640x480:
VPA_SCALE=1 ./VPA 3 ~/PLANETS/mipartida

# Ventana a 3x:
VPA_SCALE=3 ./VPA 3 ~/PLANETS/mipartida
```

| `VPA_SCALE` | Resultado |
|---|---|
| *(sin definir)* | Ventana a **2×** (por defecto). |
| `1` | **640×480** nativo, la más pequeña. |
| `2`…`8` | Ventana a **N×** (recortada a lo que quepa en tu pantalla). |
| `fullscreen` | **Pantalla completa** (el mayor ajuste 4:3 posible, por encima del panel del escritorio). Alias: `full`, `max`. |

La pantalla completa se aplica solo a la propia ventana de VPA — **no** cambia
la resolución de tu monitor, y se libera al cerrar VPA.

---

## 4. Controles y cómo salir

- **F1** — ayuda · **F3** — mensajes · **F5** — simulador de combate (consulta la
  ayuda y los menús dentro del programa para la lista completa de teclas;
  coinciden con las del VPA original de DOS).
- El ratón mueve y selecciona en el mapa; el puntero se convierte en la propia
  diana blanca de VPA dentro de la ventana.
- **Salir:**
  - **Alt-X** (o el botón **[X]** de la ventana) — sale **guardando** tu turno.
  - **Ctrl-Alt-X** — sale **sin guardar** (pide confirmación).

Al guardar, VPA escribe/actualiza tu fichero de turno (`PLAYERx.TRN`) en el
directorio de partida, listo para enviarlo de vuelta a tu host.

---

## 5. Visor de combate — no hace falta `PVCR.EXE` / `VCR.EXE`

El VPA original de DOS podía lanzar visores de combate **externos** para
repetir batallas — `PVCR.EXE` para combates de **PHost** y `VCR.EXE` para los
combates clásicos de **Tim-Host**. Con esta compilación de Linux **no
necesitas ninguno de los dos**: **el visor de combate está integrado.**

- Los combates de **PHost** usan un **visor nativo** portado del algoritmo de
  combate de PCC2ng (bit-exacto con el original), así que `PVCR.EXE` ya no hace
  falta.
- Los combates **clásicos (Tim-Host)** usan el visor interno propio de VPA, así
  que `VCR.EXE` tampoco hace falta.

**No hay ningún `.EXE` externo que instalar o copiar** — basta con ejecutar VPA.
Para ver un combate, abre el mensaje de combate en la pantalla de mensajes
(**F3**) y pulsa **`v`** para verlo; el simulador de combate (**F5**) también
usa el mismo motor integrado.

---

## 6. Créditos y licencia

VPA fue escrito por **Alex V. Ivlev** (© 1993–96) y mantenido después por el
equipo de VPA; incluye lógica de combate derivada de **PCC2ng** de **Stefan
Reuther**. Este port nativo a Linux conserva todos los avisos de copyright
originales. El programa está basado en la obra original publicada en
SourceForge bajo la licencia **MPL**.

Si te encuentras con un problema específico de esta compilación de Linux,
anota tu distribución y qué estabas haciendo cuando ocurrió.

Que lo disfrutes, y buena suerte ahí fuera, Comandante. 🚀
