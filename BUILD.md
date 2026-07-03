# Cómo compilar y ejecutar VPA-Linux

Guía de compilación del port de **VGA Planets Assistant 3.67** a GNU/Linux con
Free Pascal. Pensada para **Arch Linux**; las notas para otras distros van al final.

---

## 1. Requisitos

### Compilador
```sh
sudo pacman -S fpc
```
El paquete `fpc` (Free Pascal 3.2.2) **ya incluye** las units gráficas que usa el
port: `ptcgraph`, `ptccrt`, `ptcmouse` y `ptc`. No hay que instalarlas aparte, y
FPC las localiza solo a través de `/etc/fpc.cfg` (por eso `vpa.cfg` no lleva rutas
de units del sistema y es portable entre distros).

### Librerías X11 (en tiempo de enlace y ejecución)
`ptcgraph` abre una ventana X11 y enlaza contra varias librerías X:
```sh
sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm
```
> **Ya NO hace falta `libxxf86dga`.** El port vendoriza el backend `ptc` recompilado
> **sin las extensiones DGA** (en `VENDOR/ptc/`; ver README §1 y Fase 7), así que el
> binario no enlaza `libxxf86dga` —que además fue retirada de los repos oficiales de
> Arch en 2019—. Puedes comprobarlo con `ldd build/VPA | grep dga`: no debe aparecer
> nada. (VPA usa siempre la consola X11 en ventana, nunca DGA, así que no se pierde
> nada.)

### (Opcional) Xvfb — solo para compilar la ayuda
Solo si vas a regenerar el fichero de ayuda con `make hlp` (ver §4): el compilador
de ayuda enlaza la capa gráfica y necesita un display X, que se le da con `xvfb-run`
(un display virtual, sin pantalla real). El paquete:
- **Arch:** `sudo pacman -S xorg-server-xvfb`
- **Debian/Ubuntu:** `sudo apt install xvfb`
- **Fedora:** `sudo dnf install xorg-x11-server-Xvfb`

> No hace falta ni para el `make` normal ni para ejecutar VPA; únicamente para
> `make hlp`/`make data`.

### Wayland
El binario necesita X11. En una sesión Wayland se ejecuta igualmente a través de
**XWayland** (transparente en la mayoría de entornos). No requiere configuración.

---

## 2. Compilar

Desde la raíz del proyecto (donde están `vpa.cfg`, `Makefile`, y las carpetas
`VPA/`, `UNIT/`, `VENDOR/`, etc.):

```sh
make            # compila -> build/VPA
make clean      # borra los .ppu/.o y el binario
make run ARGS="3 /ruta/a/la/partida"   # compila y ejecuta
```

Equivale a invocar FPC directamente:
```sh
fpc @vpa.cfg VPA/VPA.PAS
```

El ejecutable y los `.ppu`/`.o` quedan en `build/`. La primera compilación también
recompila el backend `ptc` vendorizado a `build/ptcunits/` (sin DGA); las siguientes
solo lo rehacen si cambian sus fuentes. Debe terminar con `Linking build/VPA` y sin
errores (solo avisos benignos de FPC: switches `$E/$L/$N` ignorados, alguna
comparación «siempre cierta», etc.).

---

## 3. Ejecutar

```sh
./build/VPA <raza> [directorio-de-partida] [opciones]
```

- `<raza>` es el número de jugador (1–11).
- El directorio por defecto es el actual; ahí deben estar los ficheros de la
  partida (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, el `.RST`/`.TRN`…).
- `VPA /?` muestra la ayuda con todas las opciones (`/B`, `/K`, `/M`, `/O`, `/P`,
  `/PW:pwd`, `/R`, `/S`, `/REP:frm,rep`).

**Ficheros de apoyo:** VPA usa sus recursos originales (`VPA.HLP`, `VPA.MSG`,
fuentes, etc.). Mantenlos accesibles como en la instalación DOS, junto al binario o
en la ruta que VPA espera. (El `VPA.HLP` hay que regenerarlo una vez; ver §4.)

### Tamaño de la ventana / pantalla completa (`VPA_SCALE`)

La superficie de dibujo de VPA es siempre 640×480; para agrandar la ventana se usa
la variable de entorno **`VPA_SCALE`** (se antepone al comando; sin ella la escala
por defecto es **2×**). El valor no distingue mayúsculas/minúsculas.

```sh
# Pantalla completa (la mayor escala 4:3 que cabe, por encima del panel):
VPA_SCALE=fullscreen ./build/VPA 3 ~/PLANETS/mipartida

# Ventana nativa 640x480, la más pequeña (sin escalar):
VPA_SCALE=1 ./build/VPA 3 ~/PLANETS/mipartida

# Ventana a 3x (cualquier N de 2 a 8; se recorta a lo que quepa en pantalla):
VPA_SCALE=3 ./build/VPA 3 ~/PLANETS/mipartida

# Sin definir VPA_SCALE -> ventana a 2x (por defecto):
./build/VPA 3 ~/PLANETS/mipartida
```

| `VPA_SCALE` | Resultado |
|---|---|
| *(sin definir)* | Ventana a **2×** (por defecto). |
| `1` | 640×480 **nativo**, sin escalar (la más pequeña). |
| `2`…`8` | Ventana a **N×** (recortada a lo que cabe en pantalla), siempre como ventana. |
| `fullscreen` | **Pantalla completa** real: mayor ajuste 4:3 que cabe, por encima del panel del escritorio. (Alias: `full`, `max`. No distingue may/min, p. ej. `FULLSCREEN` vale.) |

> Se sale siempre con **Alt-X** (guardando) o el botón **[X]**; **Ctrl-Alt-X** sale sin
> guardar. La pantalla completa se aplica a la propia ventana de VPA (no cambia el modo
> de vídeo del monitor) y se libera al cerrar.

Sin argumentos, el programa imprime el banner y la ayuda de uso y sale — es la
forma rápida de comprobar que el binario arranca:
```
$ ./build/VPA
-= VGA Planets Assistant 3.67  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team =-
Use: VPA race [dir] ...
```

---

## 4. Compilar la ayuda (VPA.HLP)

VPA muestra su ayuda en pantalla (tecla **F1**) desde el fichero `VPA.HLP`. El
original venía como binario de DOS (empaquetado de records de Borland ≠ FPC), así
que hay que **regenerarlo** una vez desde `VHLP/VPA.HHH`:

```sh
make hlp        # genera build/VPA.HLP
```

Esto compila `VHLP/VHLPMAKE.PAS` y lo ejecuta para producir `VPA.HLP`. Como
`VHLPMAKE` enlaza la unit gráfica, necesita un display X: el `Makefile` usa
`xvfb-run` (display virtual) de forma automática, con *fallback* a ejecución
directa si ya tienes una sesión gráfica. Por eso necesita el paquete **xvfb** (ver
§1); si no lo tienes y tampoco hay display, `make hlp` fallará.

Copia el resultado a tu carpeta de partida:
```sh
cp build/VPA.HLP ~/PLANETS/
```

> **Atajo:** `make data` hace todo de golpe — compila el binario, genera `VPA.HLP`
> y copia `LITT_VPA.CHR`, dejándolo en `build/` listo para copiar a la partida.

---

## 5. (Opcional) Reconstruir el árbol desde el fuente original

Si partes del ZIP original (`VPASRC-3_67.ZIP`) en vez del repo ya preparado, el
árbol se ensambla en dos pasadas: una **mecánica** (automatizable) y una de
**ficheros portados a mano** (los de este repo).

```sh
# 1) Extraer el fuente original en una carpeta de trabajo y copiar ahi las
#    herramientas del repo (preport.py, preport-all.sh, swapgraph.py, vpa.cfg, Makefile)
unzip VPASRC-3_67.ZIP -d vpa367
cp preport.py preport-all.sh swapgraph.py vpa.cfg Makefile vpa367/
cd vpa367

# 2) Pasada mecánica: EOL->LF, quitar directivas {$C ...}, añadir {$V-}
#    (preserva el encoding latin-1 original; no convierte a UTF-8)
#    Sin argumentos solo informa; con --apply modifica in-place (crea copias .orig)
bash preport-all.sh --apply

# 3) Cambiar 'uses Graph' -> 'uses ptcgraph' (y 'Crt' -> 'ptccrt') solo en las
#    clausulas uses. swapgraph.py procesa UN fichero por llamada; usa un bucle:
for f in VPA/*.PAS UNIT/*.PAS; do python3 swapgraph.py "$f" --in-place; done

# 4) Sobrescribir con los ficheros portados a mano (los de este repo), incluida
#    la carpeta VENDOR/ (ptcgraph parcheado + backend ptc sin DGA).

# 5) Compilar
make           # o:  fpc @vpa.cfg VPA/VPA.PAS
```

Los blobs binarios de DOS (`SVGA.OBJ`, `GREETS.ASM`, `EGAVGA.OBJ`, `LITT_VPA.OBJ`,
`SANSFONT.OBJ`, `PROPFONT.OBJ`) **no se usan**: las units portadas ya no los
referencian, así que puedes ignorarlos o borrarlos.

> `SWITCHES.INC` de este repo trae VPACC desactivado y `{$PACKRECORDS 1}`
> (empaquetado de records byte a byte, imprescindible para leer los `.DAT` con el
> mismo layout que en DOS). No lo regeneres con la pasada mecánica.

---

## 6. Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| `Can't find unit system` / `...ptcgraph` | Falta el paquete `fpc` o se está usando un `fpc.cfg` local que eclipsa al `/etc/fpc.cfg`. El fichero de config del proyecto debe llamarse `vpa.cfg`, **no** `fpc.cfg`. |
| `Threading has been used before cthreads was initialized` | Ya resuelto en el port (`cthreads` es la primera unit del `uses` de `VPA.PAS`). Si reaparece, verifica que `VPA.PAS` no se haya regenerado sin ese cambio. |
| `Exception ... TPTCError` al arrancar | `ptcgraph` no pudo abrir la ventana: no hay display X11. Lanza desde una sesión gráfica (o XWayland). En un servidor sin pantalla puedes probar con `xvfb-run ./build/VPA`. |
| `make hlp` falla o no genera `VPA.HLP` | Falta **xvfb** y no hay display X. Instala el paquete xvfb de tu distro (ver §1) o ejecuta `make hlp` desde una sesión gráfica. |
| Datos de la partida ilegibles / valores raros | Revisa que `SWITCHES.INC` tenga `{$PACKRECORDS 1}` (ver §5). |
| No aparece la ayuda al pulsar F1 | Falta `VPA.HLP` en la carpeta de partida. Genéralo con `make hlp` y cópialo (ver §4). |

---

## 7. Otras distribuciones

El `vpa.cfg` no fija rutas del sistema, así que en cualquier distro con Free Pascal
3.2.x basta con instalar `fpc` y las librerías X11 equivalentes (X11, Xext, Xfixes,
Xi, Xrandr, Xxf86vm). **Ninguna necesita ya `libxxf86dga`.** El paquete **xvfb** es
opcional y solo para `make hlp`.

- **Arch Linux** (es lo que cubre §1; aquí en una línea, para tenerlo junto al resto):
  ```sh
  sudo pacman -S fpc libx11 libxext libxfixes libxi libxrandr libxxf86vm
  sudo pacman -S xorg-server-xvfb        # opcional, solo para 'make hlp'
  ```

- **Debian/Ubuntu:**
  ```sh
  sudo apt install fpc libx11-dev libxext-dev libxfixes-dev libxrandr-dev \
                   libxi-dev libxxf86vm-dev
  sudo apt install xvfb        # opcional, solo para 'make hlp'
  ```

- **Fedora:**
  ```sh
  sudo dnf install fpc libX11-devel libXext-devel libXfixes-devel \
                   libXrandr-devel libXi-devel libXxf86vm-devel
  sudo dnf install xorg-x11-server-Xvfb   # opcional, solo para 'make hlp'
  ```

Después, en cualquiera de ellas, se compila igual con `make`.

Si tu FPC es de otra versión mayor (4.x), revisa que siga ofreciendo `ptcgraph`;
el resto del proyecto no depende de la ruta concreta de las units.
