# How to build and run VPA-Linux

Build guide for the port of **VGA Planets Assistant 3.67** to GNU/Linux with Free
Pascal. Written with **Arch Linux** in mind; notes for other distributions are at
the end.

> 🌍 Este documento también está en español: [`BUILD.es.md`](BUILD.es.md).

---

## 1. Requirements

### Compiler
```sh
sudo pacman -S fpc
```
The `fpc` package (Free Pascal 3.2.2) **already includes** the graphics units the
port uses: `ptcgraph`, `ptccrt`, `ptcmouse` and `ptc`. You don't need to install
them separately, and FPC finds them on its own through `/etc/fpc.cfg` (that's why
`vpa.cfg` carries no system unit paths and is portable across distributions).

### X11 libraries (at link and run time)
`ptcgraph` opens an X11 window and links against several X libraries:
```sh
sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm
```
> **`libxxf86dga` is NO longer needed.** The port vendors the `ptc` backend
> recompiled **without the DGA extensions** (in `VENDOR/ptc/`; see README §1 and
> Phase 7), so the binary does not link `libxxf86dga` — which, on top of that, was
> removed from Arch's official repositories in 2019. You can check with
> `ldd build/VPA | grep dga`: nothing should show up. (VPA always uses the windowed
> X11 console, never DGA, so nothing is lost.)

### (Optional) Xvfb — only to build the help file
Only if you're going to regenerate the help file with `make hlp` (see §4): the help
compiler links the graphics layer and needs an X display, which is provided with
`xvfb-run` (a virtual display, no real screen). The package:
- **Arch:** `sudo pacman -S xorg-server-xvfb`
- **Debian/Ubuntu:** `sudo apt install xvfb`
- **Fedora:** `sudo dnf install xorg-x11-server-Xvfb`

> Not needed for the normal `make` nor to run VPA; only for `make hlp` / `make data`.

### Wayland
The binary needs X11. In a Wayland session it runs just the same through
**XWayland** (transparent in most environments). No configuration required.

---

## 2. Build

From the project root (where `vpa.cfg`, `Makefile`, and the `VPA/`, `UNIT/`,
`VENDOR/` … folders live):

```sh
make            # builds -> build/VPA
make clean      # removes the .ppu/.o files and the binary
make run ARGS="3 /path/to/the/game"   # builds and runs
```

This is equivalent to invoking FPC directly:
```sh
fpc @vpa.cfg VPA/VPA.PAS
```

The executable and the `.ppu`/`.o` files land in `build/`. The first build also
recompiles the vendored `ptc` backend into `build/ptcunits/` (without DGA); later
builds only rebuild it if its sources change. It must finish with `Linking build/VPA`
and no errors (only benign FPC warnings: ignored `$E/$L/$N` switches, an occasional
"always true" comparison, etc.).

---

## 3. Run

```sh
./build/VPA <race> [game-directory] [options]
```

- `<race>` is the player number (1–11).
- The default directory is the current one; that's where the game files must be
  (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, the `.RST`/`.TRN`…).
- `VPA /?` shows the help with all the options (`/B`, `/K`, `/M`, `/O`, `/P`,
  `/PW:pwd`, `/R`, `/S`, `/REP:frm,rep`).

**Support files:** VPA uses its original resources (`VPA.HLP`, `VPA.MSG`, fonts,
etc.). Keep them accessible as in the DOS install, next to the binary or in the path
VPA expects. (`VPA.HLP` must be regenerated once; see §4.)

### Window size / fullscreen (`VPA_SCALE`)

VPA's drawing surface is always 640×480; to enlarge the window use the environment
variable **`VPA_SCALE`** (prepended to the command; without it the default scale is
**2×**). The value is case-insensitive.

```sh
# Fullscreen (the largest 4:3 scale that fits, above the panel):
VPA_SCALE=fullscreen ./build/VPA 3 ~/PLANETS/mygame

# Native 640x480 window, the smallest (no scaling):
VPA_SCALE=1 ./build/VPA 3 ~/PLANETS/mygame

# 3x window (any N from 2 to 8; clamped to what fits on screen):
VPA_SCALE=3 ./build/VPA 3 ~/PLANETS/mygame

# VPA_SCALE unset -> 2x window (default):
./build/VPA 3 ~/PLANETS/mygame
```

| `VPA_SCALE` | Result |
|---|---|
| *(unset)* | **2×** window (default). |
| `1` | **Native** 640×480, no scaling (the smallest). |
| `2`…`8` | **N×** window (clamped to what fits on screen), always as a window. |
| `fullscreen` | Real **fullscreen**: largest 4:3 fit, above the desktop panel. (Aliases: `full`, `max`. Case-insensitive, e.g. `FULLSCREEN` works too.) |

> You always exit with **Alt-X** (saving) or the **[X]** button; **Ctrl-Alt-X** exits
> without saving. Fullscreen is applied to VPA's own window (it does not change the
> monitor's video mode) and is released on close.

With no arguments, the program prints the banner and usage help and exits — the quick
way to check the binary starts:
```
$ ./build/VPA
-= VGA Planets Assistant 3.67.3  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
Use: VPA race [dir] ...
```

---

## 4. Build the help files (VPA.HLP and VPA_RUS.HLP)

VPA shows its on-screen help (the **F1** key) from the `VPA.HLP` file. The original
came as a DOS binary (Borland record packing ≠ FPC), so it must be **regenerated**
once from the `VHLP/*.HHH` sources:

```sh
make hlp        # generates build/VPA.HLP and build/VPA_RUS.HLP
```

**Both** help files shipped by the original are built:

| Source | Result | Language |
|---|---|---|
| `VHLP/VPA.HHH` | `build/VPA.HLP` | English — the one VPA loads by default |
| `VHLP/VPA_RUS.HHH` | `build/VPA_RUS.HLP` | Russian |

VPA always reads the file named by the `HelpFile` key in `VPA.INI` (`VPA.HLP` by
default), so playing with the Russian help is just a matter of setting
`HelpFile = VPA_RUS.HLP` or renaming the file — see `HOWTO.en.md`.

This compiles `VHLP/VHLPMAKE.PAS` and runs it on each source. Since `VHLPMAKE`
links the graphics unit, it needs an X display: the `Makefile` uses `xvfb-run` (a
virtual display) automatically, falling back to a direct run if you already have a
graphical session. That's why it needs the **xvfb** package (see §1); without it and
with no display, `make hlp` will fail.

Copy the result to your game folder:
```sh
cp build/VPA.HLP build/VPA_RUS.HLP ~/PLANETS/
```

> **Note:** `VPA.HLP` is **required**. VPA loads it during startup and aborts with
> `Can't read file VPA.HLP` if it can't find it.

> **Shortcut:** `make data` does it all at once — see §4.1.

### 4.1 Assembling the distributable package (`make data`)

`make data` builds **all the artifacts at the same time** — the `VPA` binary (the
`build` rule) and the `VPA.HLP` and `VPA_RUS.HLP` help files (the `hlp` rule) — and then assembles a
ready-to-ship folder, **`build/vpa-linux_package/`**, with everything an end user
needs:

```sh
make data
```

| Inside `build/vpa-linux_package/` | Where it comes from |
|---|---|
| `VPA` | the binary just compiled (`build/VPA`) |
| `VPA.HLP` | the English help file just compiled (`build/VPA.HLP`) |
| `VPA_RUS.HLP` | the Russian help file just compiled (`build/VPA_RUS.HLP`) |
| `EXAMPLES/` | copied from the repo root (sample `VPA.INI`) |
| `DISTTABL.DAT` | copied from the repo root — **required** to start |
| `LITT_VPA.CHR` | copied from the repo root — map-label font |
| `VPA.MSG` | copied from the repo root — message templates |
| `HOWTO.en.md`, `HOWTO.es.md` | copied from the repo root — end-user guide |
| `LICENSE.md`, `MPL-2.0.txt` | copied from the repo root — licensing |

The folder is rebuilt from scratch on every run (it's deleted first), so it always
matches the current sources. From there you can copy it into your game folder or
pack it up for release:

```sh
cp -a build/vpa-linux_package/. ~/PLANETS/          # use it right away
tar -czf vpa-linux-x86_64.tar.gz -C build vpa-linux_package   # or ship it
```

> Since `make data` also runs the `hlp` rule, it needs **xvfb** (or a graphical
> session) just like `make hlp` does. `make clean` removes
> `build/vpa-linux_package/` along with the rest of the build artifacts.

---

## 5. (Optional) Rebuild the tree from the original source

If you start from the original ZIP (`VPASRC-3_67.ZIP`) instead of the ready-made
repo, the tree is assembled in two passes: a **mechanical** one (automatable) and a
**hand-ported files** one (the ones in this repo).

```sh
# 1) Extract the original source into a work folder and copy the repo tools there
#    (preport.py, preport-all.sh, swapgraph.py, vpa.cfg, Makefile)
unzip VPASRC-3_67.ZIP -d vpa367
cp preport.py preport-all.sh swapgraph.py vpa.cfg Makefile vpa367/
cd vpa367

# 2) Mechanical pass: EOL->LF, strip {$C ...} directives, add {$V-}
#    (preserves the original latin-1 encoding; does NOT convert to UTF-8)
#    With no arguments it only reports; with --apply it edits in place (keeps .orig copies)
bash preport-all.sh --apply

# 3) Change 'uses Graph' -> 'uses ptcgraph' (and 'Crt' -> 'ptccrt') only in the
#    uses clauses. swapgraph.py processes ONE file per call; use a loop:
for f in VPA/*.PAS UNIT/*.PAS; do python3 swapgraph.py "$f" --in-place; done

# 4) Overwrite with the hand-ported files (the ones in this repo), including the
#    VENDOR/ folder (patched ptcgraph + ptc backend without DGA).

# 5) Build
make           # or:  fpc @vpa.cfg VPA/VPA.PAS
```

The DOS binary blobs (`SVGA.OBJ`, `GREETS.ASM`, `EGAVGA.OBJ`, `LITT_VPA.OBJ`,
`SANSFONT.OBJ`, `PROPFONT.OBJ`) are **not used**: the ported units no longer
reference them, so you can ignore or delete them.

> This repo's `SWITCHES.INC` ships with VPACC disabled and `{$PACKRECORDS 1}`
> (byte-for-byte record packing, essential to read the `.DAT` files with the same
> layout as in DOS). Do not regenerate it with the mechanical pass.

---

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Can't find unit system` / `...ptcgraph` | The `fpc` package is missing, or a local `fpc.cfg` is shadowing `/etc/fpc.cfg`. The project's config file must be named `vpa.cfg`, **not** `fpc.cfg`. |
| `Threading has been used before cthreads was initialized` | Already fixed in the port (`cthreads` is the first unit in `VPA.PAS`'s `uses`). If it comes back, check that `VPA.PAS` wasn't regenerated without that change. |
| `Exception ... TPTCError` at startup | `ptcgraph` couldn't open the window: no X11 display. Launch from a graphical session (or XWayland). On a headless server you can try `xvfb-run ./build/VPA`. |
| `make hlp` fails or doesn't produce the `.HLP` files | **xvfb** is missing and there's no X display. Install your distro's xvfb package (see §1) or run `make hlp` from a graphical session. |
| Unreadable game data / weird values | Check that `SWITCHES.INC` has `{$PACKRECORDS 1}` (see §5). |
| VPA aborts with `Can't read file VPA.HLP` | `VPA.HLP` is missing from the directory you run VPA from. Generate it with `make hlp` and copy it (see §4); it's required to start. |

---

## 7. Other distributions

`vpa.cfg` pins no system paths, so on any distribution with Free Pascal 3.2.x it's
enough to install `fpc` and the equivalent X11 libraries (X11, Xext, Xfixes, Xi,
Xrandr, Xxf86vm). **None of them needs `libxxf86dga` anymore.** The **xvfb** package
is optional and only for `make hlp`.

- **Arch Linux** (this is what §1 covers; here in one line, to keep it next to the rest):
  ```sh
  sudo pacman -S fpc libx11 libxext libxfixes libxi libxrandr libxxf86vm
  sudo pacman -S xorg-server-xvfb        # optional, only for 'make hlp'
  ```

- **Debian/Ubuntu:**
  ```sh
  sudo apt install fpc libx11-dev libxext-dev libxfixes-dev libxrandr-dev \
                   libxi-dev libxxf86vm-dev
  sudo apt install xvfb        # optional, only for 'make hlp'
  ```

- **Fedora:**
  ```sh
  sudo dnf install fpc libX11-devel libXext-devel libXfixes-devel \
                   libXrandr-devel libXi-devel libXxf86vm-devel
  sudo dnf install xorg-x11-server-Xvfb   # optional, only for 'make hlp'
  ```

After that, on any of them, you build the same way with `make`.

If your FPC is a different major version (4.x), check that it still ships
`ptcgraph`; the rest of the project does not depend on the exact path of the units.
