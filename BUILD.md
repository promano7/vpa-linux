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
Una de ellas, **`libxxf86dga`**, ya no está en los repos oficiales; instálala desde
el AUR:
```sh
yay -S libxxf86dga      # o: paru -S libxxf86dga
```
> Si prefieres no depender de una librería obsoleta, en la Fase 7 del proyecto está
> previsto recompilar `ptcgraph` **sin DGA**; mientras tanto, `libxxf86dga` del AUR
> es la vía rápida.

### Wayland
El binario necesita X11. En una sesión Wayland se ejecuta igualmente a través de
**XWayland** (transparente en la mayoría de entornos). No requiere configuración.

---

## 2. Compilar

Desde la raíz del proyecto (donde están `vpa.cfg`, `Makefile`, y las carpetas
`VPA/`, `UNIT/`, etc.):

```sh
make            # compila -> build/VPA
make clean      # borra los .ppu/.o y el binario
make run ARGS="3 /ruta/a/la/partida"   # compila y ejecuta
```

Equivale a invocar FPC directamente:
```sh
fpc @vpa.cfg VPA/VPA.PAS
```

El ejecutable y los `.ppu`/`.o` quedan en `build/`. Una compilación limpia tarda
1–2 s y debe terminar con `Linking build/VPA` y sin errores (solo avisos benignos
de FPC: switches `$E/$L/$N` ignorados, alguna comparación «siempre cierta», etc.).

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
en la ruta que VPA espera.

Sin argumentos, el programa imprime el banner y la ayuda de uso y sale — es la
forma rápida de comprobar que el binario arranca:
```
$ ./build/VPA
-= VGA Planets Assistant 3.67  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team =-
Use: VPA race [dir] ...
```

---

## 4. (Opcional) Reconstruir el árbol desde el fuente original

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

# 4) Sobrescribir con los ficheros portados a mano (los de este repo):
#    UNIT/: STRF AUXF MOUSE KEYBOARD
#    VPA/ : SWITCHES.INC SCREEN TCOMBAT MESSAGES RST_TRN VPAINIT MSGREAD
#           VPA2 VPADATA VPAEXIT SCRSAVER SVGA VPA VPA4 CONFIG
#    (cópialos sobre los del árbol mecánico)

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

## 5. Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| `Can't find unit system` / `...ptcgraph` | Falta el paquete `fpc` o se está usando un `fpc.cfg` local que eclipsa al `/etc/fpc.cfg`. El fichero de config del proyecto debe llamarse `vpa.cfg`, **no** `fpc.cfg`. |
| `cannot find -lXxf86dga` al enlazar | Instala `libxxf86dga` (AUR). |
| `Threading has been used before cthreads was initialized` | Ya resuelto en el port (`cthreads` es la primera unit del `uses` de `VPA.PAS`). Si reaparece, verifica que `VPA.PAS` no se haya regenerado sin ese cambio. |
| `Exception ... TPTCError` al arrancar | `ptcgraph` no pudo abrir la ventana: no hay display X11. Lanza desde una sesión gráfica (o XWayland). En un servidor sin pantalla puedes probar con `xvfb-run ./build/VPA`. |
| Datos de la partida ilegibles / valores raros | Revisa que `SWITCHES.INC` tenga `{$PACKRECORDS 1}` (ver §4). |

---

## 6. Otras distribuciones

El `vpa.cfg` no fija rutas del sistema, así que en cualquier distro con Free Pascal
3.2.x basta con instalar `fpc` y las librerías X11 equivalentes:

- **Debian/Ubuntu:** `sudo apt install fpc libx11-dev libxext-dev libxrandr-dev
  libxi-dev libxxf86vm-dev libxxf86dga-dev` y compilar igual con `make`.

Si tu FPC es de otra versión mayor (4.x), revisa que siga ofreciendo `ptcgraph`;
el resto del proyecto no depende de la ruta concreta de las units.
