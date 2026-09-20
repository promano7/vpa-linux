# Cómo compilar y ejecutar VPA-Linux

Guía de compilación del port de **VGA Planets Assistant 3.67** a GNU/Linux con
Free Pascal. Pensada para **Arch Linux**; las notas para otras distros van al final.

> 🌍 This document is also available in English: [`BUILD.en.md`](BUILD.en.md).

---

## 1. Requisitos

VPA-Linux se compone de un **ejecutable** (`build/VPA`), que no enlaza ninguna
librería gráfica, y de **plugins gráficos** (`build/plugins/*.so`) que el
ejecutable carga al arrancar: uno para X11 y otro para Wayland. Qué hace falta
depende de qué quieras construir:

| Orden | Qué construye | Qué necesita |
|---|---|---|
| `make` (= `make build`) | `VPA` + el plugin **X11** | FPC y las librerías X11 |
| `make wayland-plugin` | además, el plugin **Wayland**, contra la **SDL3 del sistema** | lo anterior + SDL3 ≥ 3.4.4 instalada |
| `make data` | **todo**: `VPA`, los dos plugins, la ayuda y **su propia SDL3**, en un paquete distribuible | lo de `make` + lo necesario para compilar SDL3 (ver abajo) |

Para compilar y jugar en X11 basta con la primera fila; no hace falta SDL3 ni
CMake.

### Compilador
```sh
sudo pacman -S fpc
```
Free Pascal **3.2.2**. Las units gráficas (`ptc`, `ptcgraph`…) van vendorizadas en
`VENDOR/` y se compilan con el proyecto; no se usan las del sistema. `vpa.cfg` y
`plugins.cfg` no llevan rutas de units del sistema, así que son portables entre
distros.

### Librerías X11 (plugin X11)
Las enlaza `libvpagraph-x11.so`, no el ejecutable:
```sh
sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm
```
> **No hace falta `libxxf86dga`.** El backend `ptc` vendorizado está recompilado
> **sin las extensiones DGA** (`VENDOR/ptc/`), así que nada enlaza esa librería,
> retirada de los repos oficiales de Arch en 2019.

Comprobaciones:
```sh
ldd build/VPA                          # solo libc
ldd build/plugins/libvpagraph-x11.so   # las librerías X11
```

### SDL3 del sistema (solo para `make wayland-plugin`)
El plugin Wayland dibuja con SDL3 (3.4.4 o posterior):
```sh
sudo pacman -S sdl3
```
Si tu SDL3 no está en una ruta estándar: `make wayland-plugin SDL3_LIBDIR=/usr/local/lib`.
`make data` **no** usa la SDL3 del sistema: compila la suya (siguiente apartado).

### Para compilar la SDL3 del paquete (solo para `make data` / `make sdl3`)
`make data` descarga el tarball oficial de **SDL 3.4.16**, comprueba su SHA256 y
lo compila con CMake, solo con lo que VPA usa (vídeo Wayland, eventos y render).
Necesita `curl`, CMake, un compilador de C y las cabeceras de Wayland, xkbcommon,
EGL/GLES y libdecor:
```sh
sudo pacman -S curl cmake gcc make pkgconf wayland wayland-protocols \
               libxkbcommon libdecor mesa
```
`make sdl3` se detiene con un mensaje claro si SDL se ha configurado sin Wayland
o sin libdecor (sin libdecor la ventana no tendría barra de título en GNOME).

Los paquetes equivalentes de Debian/Ubuntu, Fedora y Raspberry Pi OS están en §7.

---

## 2. Compilar

Desde la raíz del proyecto (donde están `vpa.cfg`, `Makefile`, y las carpetas
`VPA/`, `UNIT/`, `VENDOR/`, etc.):

```sh
make                  # compila -> build/VPA y build/plugins/libvpagraph-x11.so
make wayland-plugin   # (opcional) -> build/plugins/libvpagraph-wayland.so, con la SDL3 del sistema
make clean            # borra los artefactos de compilación (conserva build/sdl3/)
make run ARGS="3 /ruta/a/la/partida"   # compila y ejecuta
make help             # lista todos los objetivos
```

`make` construye **solo el plugin X11**: es lo que hace falta para compilar y
probar, y no pide SDL3. Quien quiera el backend Wayland en su árbol de trabajo
ejecuta además `make wayland-plugin`; el paquete completo, con los dos plugins y
su SDL3, lo monta `make data` (§4.1).

El ejecutable busca los plugins en `plugins/` **junto a sí mismo**, así que
`build/VPA` encuentra `build/plugins/` sin configurar nada. `build/VPA --graph-info`
dice qué backend se elegiría y por qué.

El ejecutable y los `.ppu`/`.o` quedan en `build/`. La primera compilación también
compila el backend `ptc` vendorizado (sin DGA) para el plugin, en
`build/plugins/units/`; las siguientes solo lo rehacen si cambian sus fuentes. Debe terminar con `Linking build/VPA` y sin
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
-= VGA Planets Assistant 3.67.6  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
Use: VPA race [dir] ...
```

---

## 4. Compilar la ayuda (VPA.HLP y VPA_RUS.HLP)

VPA muestra su ayuda en pantalla (tecla **F1**) desde el fichero `VPA.HLP`. El
original venía como binario de DOS (empaquetado de records de Borland ≠ FPC), así
que hay que **regenerarlo** una vez desde las fuentes `VHLP/*.HHH`:

```sh
make hlp        # genera build/VPA.HLP y build/VPA_RUS.HLP
```

Se compilan **las dos ayudas** que trae el original:

| Fuente | Resultado | Idioma |
|---|---|---|
| `VHLP/VPA.HHH` | `build/VPA.HLP` | inglés — la que VPA carga por omisión |
| `VHLP/VPA_RUS.HHH` | `build/VPA_RUS.HLP` | ruso |

VPA lee siempre el fichero que indique la clave `HelpFile` de `VPA.INI`
(`VPA.HLP` por omisión), así que para jugar con la ayuda rusa basta con poner
`HelpFile = VPA_RUS.HLP` o renombrar el fichero — ver `HOWTO.es.md`.

Esto compila `VHLP/VHLPMAKE.PAS` y lo ejecuta sobre cada fuente. No necesita
sesión gráfica ni `xvfb`.

Copia el resultado a tu carpeta de partida:
```sh
cp build/VPA.HLP build/VPA_RUS.HLP ~/PLANETS/
```

> **Ojo:** `VPA.HLP` es **obligatorio**. VPA la carga durante el arranque y aborta
> con `Can't read file VPA.HLP` si no la encuentra.

> **Atajo:** `make data` hace todo de golpe — ver §4.1.

### 4.1 Montar el paquete distribuible (`make data`)

`make data` construye **todos los artefactos a la vez** — el binario `VPA` y el
plugin X11 (regla `build`), los ficheros de ayuda (regla `hlp`), la SDL3 del
paquete (regla `sdl3`) y el plugin Wayland enlazado contra ella — y después monta
una carpeta lista para distribuir, **`build/vpa-linux_package/`**, con todo lo
que necesita un usuario final:

```sh
make data
```

| Dentro de `build/vpa-linux_package/` | De dónde sale |
|---|---|
| `VPA` | el binario recién compilado (`build/VPA`) |
| `plugins/libvpagraph-x11.so` | el plugin X11 (`build/plugins/`) |
| `plugins/libvpagraph-wayland.so` | el plugin Wayland (`build/plugins/`) |
| `plugins/libSDL3.so.0` | la SDL 3.4.16 de `make sdl3` (`build/sdl3/prefix/lib/`), sin símbolos de depuración |
| `LICENSE.SDL3.txt` | la licencia zlib de SDL, tomada de su tarball |
| `VPA.HLP` | la ayuda inglesa recién compilada (`build/VPA.HLP`) |
| `VPA_RUS.HLP` | la ayuda rusa recién compilada (`build/VPA_RUS.HLP`) |
| `EXAMPLES/` | copiado de la raíz del repo (`VPA.INI` de ejemplo) |
| `DISTTABL.DAT` | copiado de la raíz del repo — **obligatorio** para arrancar |
| `LITT_VPA.CHR` | copiado de la raíz del repo — fuente de las etiquetas del mapa |
| `VPA.MSG` | copiado de la raíz del repo — plantillas de mensajes |
| `HOWTO.en.md`, `HOWTO.es.md` | copiados de la raíz del repo — guía de usuario |
| `LICENSE.md`, `MPL-2.0.txt` | copiados de la raíz del repo — licencias |

**La SDL3 del paquete.** El plugin Wayland se enlaza con `RUNPATH=$ORIGIN`: busca
`libSDL3.so.0` **primero en su propio directorio** (`plugins/`) y después en el
sistema. Por eso el paquete funciona donde la distribución no trae SDL3, todos los
usuarios tienen la misma versión, y quien prefiera la de su distro solo tiene que
borrar `plugins/libSDL3.so.0` (está explicado en el HOWTO). La versión y el SHA256
del tarball están fijados en el `Makefile` (`SDL3VER`, `SDL3SHA256`). La descarga y
la compilación (unos dos minutos) se hacen **una sola vez**: quedan en
`build/sdl3/`, que `make clean` **no** borra; para rehacerla, `rm -rf build/sdl3`.

**Es la misma receta en todas las arquitecturas.** En una Raspberry Pi (aarch64)
`make data` produce el mismo paquete, con los dos plugins y la misma SDL3,
compilado para ARM.

**En qué máquina montar el paquete que se publica.** Todo binario enlazado en
Linux queda atado, como mínimo, a la versión de glibc de la máquina donde se
enlazó, y el que más `libSDL3.so.0`, que la compila gcc (medido en Ubuntu 24.04:
`VPA` y los plugins piden `GLIBC_2.34`; la SDL3, `GLIBC_2.38`). Un paquete hecho
en una distro muy reciente no cargaría en una más antigua; en el caso de la SDL3,
además, el enlazador dinámico no pasa entonces a la del sistema: el plugin Wayland
falla y VPA se queda en X11. El paquete que se publica hay que montarlo en la
distribución **más antigua** que se quiera soportar — p. ej. Debian 12 para
x86-64 y Raspberry Pi OS (bookworm) para aarch64. Se comprueba con:
```sh
for f in VPA plugins/*.so*; do printf '%-36s' $f; objdump -T build/vpa-linux_package/$f | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1; done
```

**Hacerlo con los scripts de `tools/`.** En un anfitrión Arch,
`tools/vpa-chroot-bookworm-amd64.sh` y `tools/vpa-chroot-bookworm-arm64.sh` crean
una vez un chroot de Debian 12 (con `debootstrap`; el de arm64 corre emulado con
`qemu-user-static`), lo reutilizan después, y construyen dentro el paquete con el
nombre de las publicaciones, `vpa-linux-<versión>-<arch>.tar.gz`, leyendo la
versión de `VPA/VPADATA.PAS`:
```sh
sudo pacman -S debootstrap debian-archive-keyring
sudo pacman -S qemu-user-static qemu-user-static-binfmt      # solo para arm64

sudo tools/vpa-chroot-bookworm-amd64.sh                       # main -> ./vpa-linux-3.67.6-x86_64.tar.gz
sudo tools/vpa-chroot-bookworm-arm64.sh build feature/wayland # otra rama, etiqueta o commit
tools/vpa-chroot-bookworm-amd64.sh help                       # el resto de órdenes y variables
```
Medido en ese chroot: `VPA`, los dos plugins y la SDL3 piden todos `GLIBC_2.34`.

La carpeta se rehace desde cero en cada ejecución (se borra antes), así que siempre
corresponde al estado actual de los fuentes. Desde ahí puedes copiarla a tu carpeta
de partida o empaquetarla para publicarla:

```sh
cp -a build/vpa-linux_package/. ~/PLANETS/          # usarlo ya
tar -czf vpa-linux-x86_64.tar.gz -C build vpa-linux_package   # o distribuirlo
```

> `make clean` borra `build/vpa-linux_package/` junto con el resto de artefactos
> de compilación (salvo `build/sdl3/`).

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
| `no graphics backend could be loaded` al arrancar | VPA no encuentra o no puede cargar ningún plugin. Ejecuta `./VPA --graph-info`: lista cada sitio donde buscó y el motivo exacto (falta `plugins/` junto al binario, falta una librería del plugin, SDL3 demasiado vieja…). |
| `no graphical session detected` | No hay ni `WAYLAND_DISPLAY` ni `DISPLAY`: lanza VPA desde una sesión gráfica. En un servidor sin pantalla se puede probar con `xvfb-run ./build/VPA …`. |
| `libSDL3.so.0: cannot open shared object file` (en `--graph-info`) | El plugin Wayland no tiene SDL3: ni la copia de `plugins/` ni la del sistema. En el árbol de trabajo, tras `make wayland-plugin`, hace falta la SDL3 del sistema (§1); en el paquete de `make data` va incluida. VPA sigue funcionando con X11. |
| `make sdl3` se detiene con `configured WITHOUT Wayland` / `WITHOUT libdecor` | Faltan cabeceras de desarrollo: instala las de §1 / §7 y repite `make sdl3`. |
| `make sdl3` se detiene con `SHA256 mismatch` | El tarball descargado no es el oficial de SDL 3.4.16 (descarga corrupta o interceptada). Se borra solo; repite la orden. |
| Datos de la partida ilegibles / valores raros | Revisa que `SWITCHES.INC` tenga `{$PACKRECORDS 1}` (ver §5). |
| VPA aborta con `Can't read file VPA.HLP` | Falta `VPA.HLP` en el directorio desde el que ejecutas VPA. Genéralo con `make hlp` y cópialo (ver §4); es obligatorio para arrancar. |

---

## 7. Otras distribuciones

`vpa.cfg` y `plugins.cfg` no fijan rutas del sistema, así que en cualquier distro
con Free Pascal 3.2.2 se compila igual. Cada bloque tiene tres líneas: lo necesario
para `make` (plugin X11), lo que añade `make wayland-plugin` (SDL3 del sistema) y
lo que añade `make data` (compilar la SDL3 del paquete). **Ninguna necesita
`libxxf86dga`.**

- **Arch Linux:**
  ```sh
  sudo pacman -S fpc make libx11 libxext libxfixes libxi libxrandr libxxf86vm
  sudo pacman -S sdl3                                   # make wayland-plugin
  sudo pacman -S curl cmake gcc pkgconf wayland wayland-protocols \
                 libxkbcommon libdecor mesa             # make data
  ```

- **Debian/Ubuntu** (y **Raspberry Pi OS**):
  ```sh
  sudo apt install fpc make libx11-dev libxext-dev libxfixes-dev libxrandr-dev \
                   libxi-dev libxxf86vm-dev
  sudo apt install libsdl3-dev                          # make wayland-plugin (Debian testing, Ubuntu 25.10+)
  sudo apt install curl cmake gcc pkg-config libwayland-dev wayland-protocols \
                   libxkbcommon-dev libdecor-0-dev libegl1-mesa-dev \
                   libgles2-mesa-dev                    # make data
  ```
  Ubuntu 24.04 LTS, Debian 12 y Raspberry Pi OS (bookworm) no traen SDL3: ahí
  `make wayland-plugin` no es posible sin compilar SDL3 a mano, pero **`make data`
  sí funciona**, porque compila la suya.

- **Fedora:**
  ```sh
  sudo dnf install fpc make libX11-devel libXext-devel libXfixes-devel \
                   libXrandr-devel libXi-devel libXxf86vm-devel
  sudo dnf install SDL3-devel                           # make wayland-plugin (Fedora 43+)
  sudo dnf install curl cmake gcc pkgconf-pkg-config wayland-devel \
                   wayland-protocols-devel libxkbcommon-devel libdecor-devel \
                   mesa-libEGL-devel mesa-libGLES-devel # make data
  ```

- **Slackware-current:** una instalación completa ya trae todo (X11, Wayland,
  libdecor, CMake y SDL3 en la serie `l/`); solo falta `fpc`, de SlackBuilds.org.

Después, en cualquiera de ellas, se compila igual con `make`.

