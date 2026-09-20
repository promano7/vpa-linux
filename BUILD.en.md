# How to build and run VPA-Linux

Build guide for the port of **VGA Planets Assistant 3.67** to GNU/Linux with Free
Pascal. Written with **Arch Linux** in mind; notes for other distributions are at
the end.

> 🌍 Este documento también está en español: [`BUILD.es.md`](BUILD.es.md).

---

## 1. Requirements

VPA-Linux is made of an **executable** (`build/VPA`), which links no graphics
library at all, and of **graphics plugins** (`build/plugins/*.so`) the executable
loads at start-up: one for X11 and one for Wayland. What you need depends on what
you want to build:

| Command | What it builds | What it needs |
|---|---|---|
| `make` (= `make build`) | `VPA` + the **X11** plugin | FPC and the X11 libraries |
| `make wayland-plugin` | also the **Wayland** plugin, against the **system's SDL3** | the above + SDL3 ≥ 3.4.4 installed |
| `make data` | **everything**: `VPA`, both plugins, the help files and **its own SDL3**, as a distributable package | what `make` needs + what it takes to build SDL3 (see below) |

To build and play on X11 the first row is enough; neither SDL3 nor CMake is needed.

### Compiler
```sh
sudo pacman -S fpc
```
Free Pascal **3.2.2**. The graphics units (`ptc`, `ptcgraph`…) are vendored in
`VENDOR/` and built with the project; the system's are not used. `vpa.cfg` and
`plugins.cfg` carry no system unit paths, so they are portable across distros.

### X11 libraries (X11 plugin)
They are linked by `libvpagraph-x11.so`, not by the executable:
```sh
sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm
```
> **`libxxf86dga` is not needed.** The vendored `ptc` backend is rebuilt **without
> the DGA extensions** (`VENDOR/ptc/`), so nothing links that library, which was
> dropped from Arch's official repos in 2019.

Checks:
```sh
ldd build/VPA                          # libc only
ldd build/plugins/libvpagraph-x11.so   # the X11 libraries
```

### System SDL3 (only for `make wayland-plugin`)
The Wayland plugin draws with SDL3 (3.4.4 or later):
```sh
sudo pacman -S sdl3
```
If your SDL3 is not in a standard path: `make wayland-plugin SDL3_LIBDIR=/usr/local/lib`.
`make data` does **not** use the system's SDL3: it builds its own (next section).

### To build the package's SDL3 (only for `make data` / `make sdl3`)
`make data` downloads the official **SDL 3.4.16** tarball, checks its SHA256 and
builds it with CMake, with only what VPA uses (Wayland video, events and render).
It needs `curl`, CMake, a C compiler and the Wayland, xkbcommon, EGL/GLES and
libdecor headers:
```sh
sudo pacman -S curl cmake gcc make pkgconf wayland wayland-protocols \
               libxkbcommon libdecor mesa
```
`make sdl3` stops with a clear message if SDL was configured without Wayland or
without libdecor (without libdecor the window would have no title bar on GNOME).

The equivalent packages for Debian/Ubuntu, Fedora and Raspberry Pi OS are in §7.

---

## 2. Build

From the project root (where `vpa.cfg`, `Makefile`, and the `VPA/`, `UNIT/`,
`VENDOR/` … folders live):

```sh
make                  # builds -> build/VPA and build/plugins/libvpagraph-x11.so
make wayland-plugin   # (optional) -> build/plugins/libvpagraph-wayland.so, with the system's SDL3
make clean            # removes the build artifacts (keeps build/sdl3/)
make run ARGS="3 /path/to/the/game"   # builds and runs
make help             # lists every target
```

`make` builds **the X11 plugin only**: that is what it takes to build and test,
and it does not ask for SDL3. Whoever wants the Wayland backend in the working
tree also runs `make wayland-plugin`; the full package, with both plugins and
their SDL3, is assembled by `make data` (§4.1).

The executable looks for the plugins in `plugins/` **next to itself**, so
`build/VPA` finds `build/plugins/` with nothing to configure. `build/VPA --graph-info`
tells which backend would be chosen and why.

The executable and the `.ppu`/`.o` files land in `build/`. The first build also
compiles the vendored `ptc` backend (without DGA) for the plugin, into
`build/plugins/units/`; later
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
-= VGA Planets Assistant 3.67.6  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
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

This compiles `VHLP/VHLPMAKE.PAS` and runs it on each source. It needs neither a
graphical session nor `xvfb`.

Copy the result to your game folder:
```sh
cp build/VPA.HLP build/VPA_RUS.HLP ~/PLANETS/
```

> **Note:** `VPA.HLP` is **required**. VPA loads it during startup and aborts with
> `Can't read file VPA.HLP` if it can't find it.

> **Shortcut:** `make data` does it all at once — see §4.1.

### 4.1 Assembling the distributable package (`make data`)

`make data` builds **every artifact at once** — the `VPA` binary and the X11
plugin (`build` rule), the help files (`hlp` rule), the package's SDL3 (`sdl3`
rule) and the Wayland plugin linked against it — and then assembles a
ready-to-ship folder, **`build/vpa-linux_package/`**, with everything an end user
needs:

```sh
make data
```

| Inside `build/vpa-linux_package/` | Where it comes from |
|---|---|
| `VPA` | the freshly built binary (`build/VPA`) |
| `plugins/libvpagraph-x11.so` | the X11 plugin (`build/plugins/`) |
| `plugins/libvpagraph-wayland.so` | the Wayland plugin (`build/plugins/`) |
| `plugins/libSDL3.so.0` | the SDL 3.4.16 of `make sdl3` (`build/sdl3/prefix/lib/`), stripped of debug symbols |
| `LICENSE.SDL3.txt` | SDL's zlib licence, taken from its tarball |
| `VPA.HLP` | the freshly built English help (`build/VPA.HLP`) |
| `VPA_RUS.HLP` | the freshly built Russian help (`build/VPA_RUS.HLP`) |
| `EXAMPLES/` | copied from the repo root (sample `VPA.INI`) |
| `DISTTABL.DAT` | copied from the repo root — **required** to start |
| `LITT_VPA.CHR` | copied from the repo root — map label font |
| `VPA.MSG` | copied from the repo root — message templates |
| `HOWTO.en.md`, `HOWTO.es.md` | copied from the repo root — user guide |
| `LICENSE.md`, `MPL-2.0.txt` | copied from the repo root — licences |

**The package's SDL3.** The Wayland plugin is linked with `RUNPATH=$ORIGIN`: it
looks for `libSDL3.so.0` **in its own directory first** (`plugins/`) and in the
system afterwards. That is why the package works where the distribution has no
SDL3, every user has the same version, and whoever prefers the distro's only has
to delete `plugins/libSDL3.so.0` (explained in the HOWTO). The version and the
tarball's SHA256 are pinned in the `Makefile` (`SDL3VER`, `SDL3SHA256`). The
download and the build (about two minutes) happen **once**: they stay in
`build/sdl3/`, which `make clean` does **not** remove; to redo it, `rm -rf build/sdl3`.

**It is the same recipe on every architecture.** On a Raspberry Pi (aarch64)
`make data` produces the same package, with both plugins and the same SDL3,
built for ARM.

**Which machine to assemble the published package on.** Every binary linked on
Linux is tied, at the least, to the glibc version of the machine it was linked
on, and `libSDL3.so.0`, which gcc compiles, most of all (measured on Ubuntu 24.04:
`VPA` and the plugins ask for `GLIBC_2.34`; SDL3 for `GLIBC_2.38`). A package made
on a very recent distro would not load on an older one; in SDL3's case, moreover,
the dynamic linker does not then move on to the system's: the Wayland plugin
fails and VPA stays on X11. The published package
must be assembled on the **oldest** distribution you want to support — e.g.
Debian 12 for x86-64 and Raspberry Pi OS (bookworm) for aarch64. Check it with:
```sh
for f in VPA plugins/*.so*; do printf '%-36s' $f; objdump -T build/vpa-linux_package/$f | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1; done
```

**Doing it with the scripts in `tools/`.** On an Arch host,
`tools/vpa-chroot-bookworm-amd64.sh` and `tools/vpa-chroot-bookworm-arm64.sh`
create a Debian 12 chroot once (with `debootstrap`; the arm64 one runs emulated by
`qemu-user-static`), reuse it afterwards, and build the package inside it under
the release naming, `vpa-linux-<version>-<arch>.tar.gz`, reading the version from
`VPA/VPADATA.PAS`:
```sh
sudo pacman -S debootstrap debian-archive-keyring
sudo pacman -S qemu-user-static qemu-user-static-binfmt      # arm64 only

sudo tools/vpa-chroot-bookworm-amd64.sh                       # main -> ./vpa-linux-3.67.6-x86_64.tar.gz
sudo tools/vpa-chroot-bookworm-arm64.sh build feature/wayland # another branch, tag or commit
tools/vpa-chroot-bookworm-amd64.sh help                       # the other commands and variables (in Spanish)
```
Measured in that chroot: `VPA`, both plugins and SDL3 all ask for `GLIBC_2.34`.

The folder is rebuilt from scratch on every run (it is removed first), so it
always matches the current state of the sources. From there you can copy it to
your game folder or pack it for publishing:

```sh
cp -a build/vpa-linux_package/. ~/PLANETS/          # use it right away
tar -czf vpa-linux-x86_64.tar.gz -C build vpa-linux_package   # or distribute it
```

> `make clean` removes `build/vpa-linux_package/` along with the rest of the
> build artifacts (except `build/sdl3/`).

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
| `no graphics backend could be loaded` at start-up | VPA cannot find or load any plugin. Run `./VPA --graph-info`: it lists every place it looked in and the exact reason (no `plugins/` next to the binary, a library the plugin needs is missing, SDL3 too old…). |
| `no graphical session detected` | Neither `WAYLAND_DISPLAY` nor `DISPLAY` is set: start VPA from a graphical session. On a headless server you can try `xvfb-run ./build/VPA …`. |
| `libSDL3.so.0: cannot open shared object file` (in `--graph-info`) | The Wayland plugin has no SDL3: neither the copy in `plugins/` nor the system's. In the working tree, after `make wayland-plugin`, the system's SDL3 is needed (§1); in the `make data` package it is bundled. VPA keeps working on X11. |
| `make sdl3` stops with `configured WITHOUT Wayland` / `WITHOUT libdecor` | Development headers are missing: install those of §1 / §7 and run `make sdl3` again. |
| `make sdl3` stops with `SHA256 mismatch` | The downloaded tarball is not the official SDL 3.4.16 one (corrupt or intercepted download). It is removed automatically; run the command again. |
| Unreadable game data / weird values | Check that `SWITCHES.INC` has `{$PACKRECORDS 1}` (see §5). |
| VPA aborts with `Can't read file VPA.HLP` | `VPA.HLP` is missing from the directory you run VPA from. Generate it with `make hlp` and copy it (see §4); it's required to start. |

---

## 7. Other distributions

`vpa.cfg` and `plugins.cfg` pin no system paths, so on any distro with Free Pascal
3.2.2 the build is the same. Each block has three lines: what `make` needs (X11
plugin), what `make wayland-plugin` adds (system SDL3) and what `make data` adds
(building the package's SDL3). **None needs `libxxf86dga`.**

- **Arch Linux:**
  ```sh
  sudo pacman -S fpc make libx11 libxext libxfixes libxi libxrandr libxxf86vm
  sudo pacman -S sdl3                                   # make wayland-plugin
  sudo pacman -S curl cmake gcc pkgconf wayland wayland-protocols \
                 libxkbcommon libdecor mesa             # make data
  ```

- **Debian/Ubuntu** (and **Raspberry Pi OS**):
  ```sh
  sudo apt install fpc make libx11-dev libxext-dev libxfixes-dev libxrandr-dev \
                   libxi-dev libxxf86vm-dev
  sudo apt install libsdl3-dev                          # make wayland-plugin (Debian testing, Ubuntu 25.10+)
  sudo apt install curl cmake gcc pkg-config libwayland-dev wayland-protocols \
                   libxkbcommon-dev libdecor-0-dev libegl1-mesa-dev \
                   libgles2-mesa-dev                    # make data
  ```
  Ubuntu 24.04 LTS, Debian 12 and Raspberry Pi OS (bookworm) do not ship SDL3:
  there `make wayland-plugin` is not possible without building SDL3 by hand, but
  **`make data` does work**, because it builds its own.

- **Fedora:**
  ```sh
  sudo dnf install fpc make libX11-devel libXext-devel libXfixes-devel \
                   libXrandr-devel libXi-devel libXxf86vm-devel
  sudo dnf install SDL3-devel                           # make wayland-plugin (Fedora 43+)
  sudo dnf install curl cmake gcc pkgconf-pkg-config wayland-devel \
                   wayland-protocols-devel libxkbcommon-devel libdecor-devel \
                   mesa-libEGL-devel mesa-libGLES-devel # make data
  ```

- **Slackware-current:** a full install already has everything (X11, Wayland,
  libdecor, CMake and SDL3 in the `l/` series); only `fpc` is missing, from
  SlackBuilds.org.

After that, on any of them, you build the same way with `make`.
