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
  distancias que VPA necesita para arrancar), **`VPA.HLP`** (obligatorio — el
  fichero de ayuda; VPA **no arranca** sin él), **`VPA.MSG`** (plantillas de
  mensajes) y la fuente de mapa **`LITT_VPA.CHR`**. Se incluye además
  **`VPA_RUS.HLP`**, la misma ayuda en ruso (ver §2).
- Un **directorio de partida** de VGA Planets propio: la carpeta con tus ficheros
  de turno (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, `PLAYERx.RST`,
  etc.), donde `x` es tu número de raza. VPA **no** incluye ninguna partida; esos
  ficheros los obtienes de tu host de VGA Planets.
- Los **ficheros del propio VGA Planets** (`PLANET.NM`, `RESOURCE.PLN`,
  `PLANETS.EXE`, las `*SPEC.DAT`…), que no se distribuyen con VPA-Linux —
  ver «Ficheros ajenos a VPA-Linux» en §2.

### Librerías en tiempo de ejecución
El binario usa un puñado de librerías X11 estándar que ya están presentes en
prácticamente cualquier escritorio Linux. Si se queja de algún `lib….so` que
falta, instálalas:

- **Arch:** `sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm`
- **Debian/Ubuntu:** `sudo apt install libx11-6 libxext6 libxfixes3 libxi6 libxrandr2 libxxf86vm1`
- **Fedora:** `sudo dnf install libX11 libXext libXfixes libXi libXrandr libXxf86vm`

> **Wayland:** funciona a través de **XWayland** (presente en casi todos los
> escritorios), sin nada que configurar, **con una salvedad conocida**: el
> puntero del ratón se captura al entrar en la ventana de VPA pero **no se
> libera** al salir, así que queda atrapado. Como apaño puedes abrir una
> pantalla que suelte el cursor (F1 o F10), pero si vas a jugar a menudo lo
> cómodo es **elegir la sesión X11** en la pantalla de inicio de sesión de tu
> escritorio: es el mismo entorno y ahí funciona correctamente.
>
> El motivo es que toda la gestión del puntero de VPA-Linux es código X11
> ejecutándose sobre XWayland, y Wayland no permite deliberadamente que un
> cliente capture y suelte el puntero como sí hace X11. La solución real —
> un backend gráfico nativo de Wayland — está prevista pero es un trabajo
> largo. Ver «Limitaciones conocidas» en el README.

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
  se usa el directorio actual. Vale tanto una ruta **absoluta**
  (`/home/tu-usuario/PLANETS/mipartida`) como **relativa** (`mipartida`), con
  barras `/` o, si vienes de DOS, con barras invertidas `\`. La barra final es
  opcional. Como máximo 66 caracteres; si te pasas, VPA lo dice y sale en lugar
  de fallar más adelante.

Ejemplo (jugando la raza 3, partida en `~/PLANETS/mipartida`):
```sh
./VPA 3 ~/PLANETS/mipartida
```

Ejecútalo sin argumentos para ver el banner y confirmar que arranca:
```
$ ./VPA
-= VGA Planets Assistant 3.67.3  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
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
- **`VPA.HLP`** — la ayuda integrada (**F1** dentro de VPA). **Obligatorio:** VPA
  la carga durante el arranque, y si no la encuentra aborta con
  `Can't read file VPA.HLP` después de haber leído ya los datos de la partida.
  Tiene que estar en el **directorio desde el que ejecutas VPA** (el directorio
  actual), no en el de la partida — igual que `RESOURCE.PLN`.
- **`LITT_VPA.CHR`** — la pequeña fuente vectorial usada para las etiquetas del
  mapa (nombres de planeta y de nave). Si falta, VPA sigue funcionando pero cae a
  una fuente integrada, así que esas etiquetas no se verán del todo bien.

`DISTTABL.DAT` y `VPA.HLP` son **estrictamente obligatorios** para arrancar; el
resto son opcionales, pero convienen para la experiencia completa y correcta.

### Ayuda en ruso (`VPA_RUS.HLP`)

El paquete trae la ayuda en dos idiomas: **`VPA.HLP`** (inglés) y
**`VPA_RUS.HLP`** (ruso), las dos compiladas desde las fuentes originales
`VHLP/VPA.HHH` y `VHLP/VPA_RUS.HHH`.

VPA lee siempre el fichero indicado por la clave `HelpFile` de `VPA.INI`, que por
omisión vale `VPA.HLP`. Hay por tanto dos maneras de pasarte al ruso:

**Opción A — editar `VPA.INI`** (recomendada, no toca los ficheros):

```ini
HelpFile        = VPA_RUS.HLP
```

**Opción B — renombrar**, como se hacía en el VPA original de DOS:

```sh
rm VPA.HLP
mv VPA_RUS.HLP VPA.HLP
```

> **Mayúsculas y minúsculas:** el nombre del fichero de ayuda se busca **sin
> distinguir la caja**, tanto el que trae `VPA.INI` como el valor por omisión. Da
> igual que en disco tengas `VPA_RUS.HLP`, `vpa_rus.hlp` o `Vpa_Rus.Hlp`.

### Ficheros ajenos a VPA-Linux, obligatorios para correr una partida

VPA-Linux es solo el cliente: **no incluye** ni los datos del juego VGA Planets
ni los ficheros de tu partida. Estos vienen de tu instalación original de VGA
Planets y de tu host, y tienen que estar presentes para poder jugar.

**En el directorio de VPA** (junto al binario):

| Fichero | Para qué sirve |
|---|---|
| `RESOURCE.PLN` | los recursos gráficos que usa VPA. |
| `PLANETS.EXE` | VPA-Linux **lee de aquí el registro** (no lo ejecuta; solo lo abre para leer tus datos de registro). |

**En el directorio de la partida:**

| Fichero | Para qué sirve |
|---|---|
| `PLAYERx.RST` | tu turno, donde `x` es tu número de raza. Lo proporciona el host. |
| `PCONFIG.SRC` | la configuración del host. Solo si juegas con **PHost**; lo proporciona el host. |
| `UTILx.DAT` | datos auxiliares del turno. Solo si juegas con **PHost**; lo proporciona el host. |
| `MISSION.INI` | definiciones de misiones. Solo si juegas con **PHost**. |

**En el directorio de VPA o en el de la partida** — se busca **primero en el de
la partida**, así que una copia en la partida tiene prioridad sobre la del
directorio de VPA (útil cuando el host usa una lista de naves modificada):

| Ficheros | Para qué sirven |
|---|---|
| `BEAMSPEC.DAT`, `TORPSPEC.DAT`, `ENGSPEC.DAT` | características de rayos, torpedos y motores. |
| `HULLSPEC.DAT`, `HULLFUNC.DAT`, `TRUEHULL.DAT` | características de los cascos, sus funciones especiales y qué casco puede construir cada raza. |
| `PLANET.NM` | los nombres de los planetas. |
| `RACE.NM` | los nombres de las razas. |
| `STORM.NM` | los nombres de las tormentas iónicas (opcional). |

> **Mayúsculas y minúsculas:** VPA-Linux busca todos estos ficheros **sin
> distinguir la caja del nombre**, así que da igual que tu partida traiga
> `PLAYER3.RST` o `player3.rst`, `PCONFIG.SRC` o `pconfig.src`. Se respeta el
> nombre tal y como esté en disco; no hace falta renombrar nada.

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

# Ventana a un porcentaje concreto (p.ej. 220% = 2.2x):
VPA_SCALE=220 ./VPA 3 ~/PLANETS/mipartida
```

| `VPA_SCALE` | Resultado |
|---|---|
| *(sin definir)* | Ventana a **2×** (por defecto). |
| `1` | **640×480** nativo, la más pequeña. |
| `2`…`20` | Ventana a **N×** (recortada a lo que quepa en tu pantalla). |
| `21`…`800` | Ventana al **N %** indicado (p.ej. `220` = 2.2×, `137` = 1.37×), para ajustar el tamaño con más precisión que con un múltiplo entero. |
| `fullscreen` | **Pantalla completa** (el mayor ajuste 4:3 posible, por encima del panel del escritorio). Alias: `full`, `max`. |

Los valores del 2 al 20 se interpretan como "veces" (igual que antes de admitir
porcentajes); a partir de 21 se interpretan como porcentaje directo. No hay
ambigüedad real entre ambos: nadie pide una ventana al "2 %" de tamaño.

La pantalla completa se aplica solo a la propia ventana de VPA — **no** cambia
la resolución de tu monitor, y se libera al cerrar VPA.

### Sensibilidad del ratón al seleccionar (`StickyMouseRange`)

VPA tiene una función llamada **StickyMouse** que evita perder la selección de
un objeto (planeta, nave...) por un movimiento involuntario del ratón: mientras
el puntero no se aleje del objeto seleccionado, el movimiento se ignora y el
cursor vuelve a él. Es lo que impide fijar rutas por error con la mesa
temblando o el pulso poco firme.

El radio clásico de VPA era de **2 píxeles**, fijo. Con ratones ópticos
modernos (que reportan movimiento constantemente) puede quedarse corto. Ahora
se puede ajustar en `VPA.INI`, en la sección `[Interface]`:

```ini
StickyMouse      = On
StickyMouseRange = 15
```

| Valor | Efecto |
|---|---|
| `2` | Comportamiento clásico de VPA (valor por omisión si no pones la clave). |
| `10`–`20` | Recomendado con ratones ópticos modernos: aguanta bien el temblor sin volverse pegajoso. |
| `0` | Desactiva el filtro (equivale a `StickyMouse = Off`). |
| máx. `100` | Valores mayores se recortan a 100; por encima costaría soltar la selección. |

Si prefieres desactivarlo del todo, `StickyMouse = Off` sigue funcionando igual
que siempre.

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
