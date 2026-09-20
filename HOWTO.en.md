# VPA-Linux — How to run

> 🌍 Este documento también está disponible en español: [`HOWTO.es.md`](HOWTO.es.md).

**VGA Planets Assistant (VPA) 3.67**, native GNU/Linux build.

VPA is a helper/client for the classic play-by-email strategy game **VGA Planets 3**:
it loads your turn (`RST`), lets you review the star map, planets, ships, bases,
messages, and the combat simulator, and writes your orders back into a turn file
(`TRN`). This is a faithful native Linux port of the original DOS program — same
look, same keys.

> This is the **end-user guide** for the pre-built binary. If you want to compile
> from source instead, see `BUILD.en.md`.

---

## 1. What you need

- A **64-bit Linux** system (x86-64, or aarch64 such as the Raspberry Pi; each
  architecture has its own package) with a graphical session, **X11 or Wayland**.
- The **`VPA` binary** (in this package) and, **next to it, the `plugins/`
  folder** with the graphics backends (see "Graphics backends" below): VPA
  **won't start** without it. Plus the support files shipped with it:
  **`DISTTABL.DAT`** (required — a distance table VPA needs to start),
  **`VPA.HLP`** (required — the help file; VPA **won't start** without it),
  **`VPA.MSG`** (message templates) and the **`LITT_VPA.CHR`** map font.
  **`VPA_RUS.HLP`**, the same help in Russian, is also included (see §2).
- A **VGA Planets game directory** of your own: the folder with your turn files
  (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, `PLAYERx.RST`, etc.), where
  `x` is your race number. VPA does **not** come with a game; you get those files
  from your VGA Planets host.
- The **VGA Planets files themselves** (`PLANET.NM`, `RESOURCE.PLN`,
  `PLANETS.EXE`, the `*SPEC.DAT` files…), which are not shipped with VPA-Linux —
  see "Files not shipped with VPA-Linux" in §2.

### Graphics backends: X11 and Wayland

The `VPA` binary does not draw by itself: at start-up it loads a **graphics
plugin** from the **`plugins/`** folder, which must sit **next to the binary**
(not in the game directory). The package ships both:

| File in `plugins/` | What for |
|---|---|
| `libvpagraph-x11.so` | **X11** sessions. |
| `libvpagraph-wayland.so` | **Wayland** sessions, **natively** (no XWayland). It draws with SDL3. |
| `libSDL3.so.0` | The **SDL3** the Wayland plugin uses, bundled with the package (see below). |

There is nothing to configure: VPA looks at the session it runs in and picks the
matching backend; if that one fails, it tries the other. You can force one with
`VPA_GRAPH_BACKEND`, and `./VPA --graph-info` tells which one is chosen and why
(see §2). On screen both backends draw exactly the same.

### Runtime libraries
The `VPA` binary itself only needs libc. The graphics-system libraries are used
by the plugins, and they are already present on virtually any Linux desktop. If
`--graph-info` says a plugin is missing some `lib….so`:

- **X11 plugin**
  - **Arch:** `sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm`
  - **Debian/Ubuntu:** `sudo apt install libx11-6 libxext6 libxfixes3 libxi6 libxrandr2 libxxf86vm1`
  - **Fedora:** `sudo dnf install libX11 libXext libXfixes libXi libXrandr libXxf86vm`
- **Wayland plugin** (the Wayland client libraries; any Wayland desktop has them)
  - **Arch:** `sudo pacman -S wayland libxkbcommon libdecor`
  - **Debian/Ubuntu:** `sudo apt install libwayland-client0 libwayland-cursor0 libwayland-egl1 libxkbcommon0 libdecor-0-0`
  - **Fedora:** `sudo dnf install libwayland-client libwayland-cursor libwayland-egl libxkbcommon libdecor`

### The bundled SDL3, and how to use your distribution's

The Wayland plugin draws with **SDL3**. So that everybody plays with the same
version, and because many distributions do not ship it yet, the package carries
its own copy: **`plugins/libSDL3.so.0`** (SDL 3.4.16, built with only what VPA
uses; its licence is in `LICENSE.SDL3.txt`). Nothing is installed in the system
and no other program sees it.

The plugin looks for SDL3 in this order:

1. **the bundled copy**, `plugins/libSDL3.so.0`, next to the plugin itself;
2. if it is not there, **the system's SDL3**.

So, if you prefer your distribution's SDL3, just **delete the copy**:

```sh
rm plugins/libSDL3.so.0
```

It must be SDL **3.4.4 or later**; with an older one the plugin refuses to start
and says why. Where SDL3 is in the repositories:

- **Arch:** `sudo pacman -S sdl3`
- **Fedora** (43 onwards): `sudo dnf install SDL3`
- **Debian** testing/unstable and **Ubuntu** 25.10 onwards: `sudo apt install libsdl3-0`
- **Slackware-current:** already there, in the `l/` series.

Where the distribution does not ship it (Ubuntu 24.04 LTS and derivatives,
Debian 12, Raspberry Pi OS on bookworm…) it can be built by hand with CMake:

```sh
tar xf SDL3-3.4.16.tar.gz && cd SDL3-3.4.16
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
sudo cmake --install build && sudo ldconfig
```

And **if there is no SDL3 at all, nothing breaks**: the Wayland plugin does not
load, VPA stays on the X11 backend (through XWayland in a Wayland session) and
works as it always has. Nobody is left unable to play because of this.

> **XWayland:** if you force `VPA_GRAPH_BACKEND=x11` in a Wayland session, or the
> Wayland plugin cannot be loaded, VPA runs on XWayland, with one known caveat:
> the mouse pointer is grabbed when it enters the VPA window but is **not
> released** when it leaves (as a workaround, F1 or F10 free the cursor). With
> the native Wayland backend this does not happen.

---

## 2. Running VPA

Make the binary executable once, then run it with your **race number** and your
**game directory**:

```sh
chmod +x VPA          # only the first time
./VPA <race> [game-directory]
```

- `<race>` — your player number (1–11).
- `[game-directory]` — the folder with your turn files. If omitted, the current
  directory is used. Either an **absolute** path
  (`/home/your-user/PLANETS/mygame`) or a **relative** one (`mygame`) works, with
  forward slashes `/` or, if you're coming from DOS, with backslashes `\`. The
  trailing slash is optional. Maximum 66 characters; if you go over, VPA says so
  and exits instead of failing later on.

Example (playing race 3, game in `~/PLANETS/mygame`):
```sh
./VPA 3 ~/PLANETS/mygame
```

Run it with no arguments to see the banner and confirm it starts:
```
$ ./VPA
-= VGA Planets Assistant 3.67.6  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
Use: VPA race [dir] ...
```

`./VPA /?` lists all command-line options (`/B`, `/K`, `/M`, `/O`, `/P`, `/PW:pwd`,
`/R`, `/S`, `/REP:frm,rep`), exactly as the original VPA did.

### VPA-Linux help: `--help` and `--graph-info`

`./VPA --help` (or `-h`) shows the same help as `/?` **plus the VPA-Linux
environment variables**, which appear in no other help of the program:

| Variable | What it does |
|---|---|
| `VPA_SCALE` | Window size or fullscreen (section 3). |
| `VPA_GRAPH_BACKEND` | Graphics backend: `auto` (default), `x11` or `wayland`. With `auto`, VPA detects the session (`WAYLAND_DISPLAY`, `DISPLAY`, `XDG_SESSION_TYPE`) and, if the first backend fails, tries the other one. With `x11` or `wayland` that backend is **forced** and VPA never switches to another: if it fails, VPA stops and says why. |
| `VPA_GRAPH_PLUGIN_DIR` | **Absolute** directory searched first for the graphics plugins (`libvpagraph-x11.so`, `libvpagraph-wayland.so`), before `plugins/` next to the executable and the install directory. |
| `VPA_GRAPH_DEBUG` | With `1`, traces the session detection and the plugin search on `stderr`. |
| `VPA_GRAPH_DUMP` | Testing aid: given a path prefix, **Ctrl-F12** dumps the 640×480 screen to `<prefix>NNNN.ppm` and its palette to `<prefix>NNNN.pal`. |

`./VPA --graph-info` is the diagnostic tool for bug reports: it prints the
session environment, which backend was requested, in which order they would be
tried and why, which one was selected (plugin path, ABI and backend version)
or, if none works, **every reason**, one per place searched. It opens no
window. If the window does not open or looks wrong, attach its output to the
report. Exit status is 0 when a backend was selected and 1 otherwise.

> `--help` and `--graph-info` open no window and need no graphical session: they
> also work over SSH or on a console.

### Support files
Keep these files where you run VPA — in your game directory or next to the binary
(the `plugins/` folder, on the other hand, **always** goes next to the binary):

- **`DISTTABL.DAT`** — a precomputed distance table. **Required:** VPA refuses to
  start (and exits) if it's missing or damaged. Ship it as-is; don't edit it.
- **`VPA.MSG`** — the message templates VPA uses to parse and format incoming host
  messages. If it's missing, VPA still runs but warns and can't parse messages. It's
  a plain-text file in **Unix (LF)** line endings — keep it that way; a DOS (CRLF)
  copy won't parse correctly on Linux.
- **`VPA.HLP`** — the built-in help (**F1** inside VPA). **Required:** VPA loads it
  during startup, and if it can't find it, it aborts with
  `Can't read file VPA.HLP` after having already read the game data. It has to be
  in the **directory you run VPA from** (the current directory), not in the game
  directory — same as `RESOURCE.PLN`.
- **`LITT_VPA.CHR`** — the small vector font used for the map labels (planet and ship
  names). If it's missing, VPA still runs but falls back to a built-in font, so those
  labels won't look quite right.

`DISTTABL.DAT` and `VPA.HLP` are **strictly required** to start; the rest are
optional but wanted for the full, correct experience.

### Russian help (`VPA_RUS.HLP`)

The package ships the help in two languages: **`VPA.HLP`** (English) and
**`VPA_RUS.HLP`** (Russian), both compiled from the original `VHLP/VPA.HHH` and
`VHLP/VPA_RUS.HHH` sources.

VPA always reads the file named by the `HelpFile` key in `VPA.INI`, which defaults
to `VPA.HLP`. So there are two ways to switch to Russian:

**Option A — edit `VPA.INI`** (recommended, leaves the files alone):

```ini
HelpFile        = VPA_RUS.HLP
```

**Option B — rename**, the way the original DOS VPA did it:

```sh
rm VPA.HLP
mv VPA_RUS.HLP VPA.HLP
```

> **Upper/lower case:** the help file name is looked up **case-insensitively**,
> both the one from `VPA.INI` and the default. It doesn't matter whether the file
> on disk is `VPA_RUS.HLP`, `vpa_rus.hlp` or `Vpa_Rus.Hlp`.

### Files not shipped with VPA-Linux, required to play a game

VPA-Linux is just the client: it does **not** include the VGA Planets game data nor
your game files. Those come from your original VGA Planets installation and from
your host, and they must be present for you to play.

**In the VPA directory** (next to the binary):

| File | What it's for |
|---|---|
| `RESOURCE.PLN` | the graphic resources VPA uses. |
| `PLANETS.EXE` | VPA-Linux **reads your registration from it** (it does not run it; it only opens it to read your registration data). |

**In the game directory:**

| File | What it's for |
|---|---|
| `PLAYERx.RST` | your turn, where `x` is your race number. Provided by the host. |
| `PCONFIG.SRC` | the host configuration. Only if you play with **PHost**; provided by the host. |
| `UTILx.DAT` | auxiliary turn data. Only if you play with **PHost**; provided by the host. |
| `MISSION.INI` | mission definitions. Only if you play with **PHost**. |

**In either the VPA directory or the game directory** — the **game directory is
searched first**, so a copy there takes precedence over the one in the VPA
directory (handy when your host uses a modified ship list):

| Files | What they're for |
|---|---|
| `BEAMSPEC.DAT`, `TORPSPEC.DAT`, `ENGSPEC.DAT` | beam, torpedo and engine specs. |
| `HULLSPEC.DAT`, `HULLFUNC.DAT`, `TRUEHULL.DAT` | hull specs, their special functions, and which hull each race can build. |
| `PLANET.NM` | the planet names. |
| `RACE.NM` | the race names. |
| `STORM.NM` | the ion storm names (optional). |

> **Upper/lower case:** VPA-Linux looks all these files up **case-insensitively**, so
> it doesn't matter whether your game ships `PLAYER3.RST` or `player3.rst`,
> `PCONFIG.SRC` or `pconfig.src`. The name is used exactly as it is on disk — you
> don't need to rename anything.

---

## 3. Window size and fullscreen

VPA's screen is 640×480. To make the window bigger, set the **`VPA_SCALE`**
environment variable before the command (it's case-insensitive):

```sh
# Fullscreen:
VPA_SCALE=fullscreen ./VPA 3 ~/PLANETS/mygame

# Smallest, native 640x480 window:
VPA_SCALE=1 ./VPA 3 ~/PLANETS/mygame

# 3x window:
VPA_SCALE=3 ./VPA 3 ~/PLANETS/mygame

# Window at a specific percentage (e.g. 220% = 2.2x):
VPA_SCALE=220 ./VPA 3 ~/PLANETS/mygame
```

| `VPA_SCALE` | Result |
|---|---|
| *(unset)* | **2×** window (default). |
| `1` | Native **640×480**, the smallest. |
| `2`…`20` | **N×** window (clamped to what fits on your screen). |
| `21`…`800` | Window at **N %** (e.g. `220` = 2.2×, `137` = 1.37×), for finer control than an integer multiple. |
| `fullscreen` | **Fullscreen** (largest 4:3 fit, above the desktop panel). Aliases: `full`, `max`. |

Values 2 through 20 are read as "times" (same as before percentages were
supported); anything from 21 up is read as a direct percentage. There's no
real ambiguity between the two: nobody asks for a window at "2%" of size.

Fullscreen applies only to VPA's own window — it does **not** change your monitor's
resolution, and it's released when you close VPA.

### Selection mouse sensitivity (`StickyMouseRange`)

VPA has a feature called **StickyMouse** that keeps you from losing an object
selection (planet, ship...) to an accidental mouse movement: as long as the
pointer doesn't stray from the selected object, the movement is ignored and the
cursor snaps back to it. This is what stops you setting waypoints by mistake
with a shaky table or an unsteady hand.

VPA's classic radius was a hardcoded **2 pixels**. With modern optical mice
(which report movement constantly) that can be too tight. It's now adjustable
in `VPA.INI`, under `[Interface]`:

```ini
StickyMouse      = On
StickyMouseRange = 15
```

| Value | Effect |
|---|---|
| `2` | Classic VPA behaviour (the default if you don't set the key). |
| `10`–`20` | Recommended with modern optical mice: absorbs shake without feeling sticky. |
| `0` | Disables the filter (same as `StickyMouse = Off`). |
| max `100` | Larger values are clamped to 100; beyond that the selection would be hard to release. |

You can also change it without leaving the program, from the `VPA.INI` menu
(**Ctrl-O**): pressing `Enter` on `StickyMouseRange` steps the value up one at a
time to `20` and then back to `0`. The menu stops at `20` because a larger
radius has no practical use and would leave the pointer stuck all over the
screen; for a value between `21` and `100`, set it in the file.

If you'd rather turn it off entirely, `StickyMouse = Off` still works exactly as
it always did.

---

## 4. Controls & exiting

- **F1** — help · **F3** — messages · **F5** — combat simulator (see the in-program
  help and menus for the full key list; they match the original DOS VPA).
- The mouse moves and selects on the map; the pointer becomes VPA's own white
  crosshair inside the window.
- **Exit:**
  - **Alt-X** (or the window's **[X]** button) — quit **saving** your turn.
  - **Ctrl-Alt-X** — quit **without saving** (asks for confirmation).

When you save, VPA writes/updates your turn file (`PLAYERx.TRN`) in the game
directory, ready to send back to your host.

---

## 5. Combat viewer — no `PVCR.EXE` / `VCR.EXE` needed

The original DOS VPA could launch **external** combat viewers to replay battles —
`PVCR.EXE` for **PHost** battles and `VCR.EXE` for classic **Tim-Host** battles. You
do **not** need any of those with this Linux build: **the combat viewer is built in.**

- **PHost** battles use a **native viewer** ported from the combat algorithm of
  PCC2ng (bit-exact with the original), so `PVCR.EXE` is no longer required.
- **Classic (Tim-Host)** battles use VPA's own internal viewer, so `VCR.EXE` isn't
  needed either.

There are **no external `.EXE` helpers to install or copy** — just run VPA. To watch a
fight, open the combat message in the messages screen (**F3**) and press **`v`** to
view it; the **F5** combat simulator also uses the same built-in engine.

---

## 6. Credits & license

VPA was written by **Alex V. Ivlev** (© 1993–96) and maintained afterwards by the
VPA team; it includes combat logic derived from **PCC2ng** by **Stefan Reuther**.
This native Linux port keeps all original copyright notices. The program is based on
the original work published on SourceForge under the **MPL** license.

The package includes **SDL 3.4.16** (`plugins/libSDL3.so.0`), built from its
unmodified official sources, © Sam Lantinga, under the **zlib** licence: see
`LICENSE.SDL3.txt`.

If you hit a problem specific to this Linux build, note your distribution and what
you were doing when it happened.

Enjoy, and good luck out there, Commander. 🚀
