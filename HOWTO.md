# VPA-Linux — How to run

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

- A **64-bit x86 Linux** system with a graphical (X11 or Wayland) session.
- The **`VPA` binary** (in this package), plus the two support files shipped with
  it: the **`VPA.HLP`** help file and the **`LITT_VPA.CHR`** map font.
- A **VGA Planets game directory** of your own: the folder with your turn files
  (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, `PLAYERx.RST`, etc.), where
  `x` is your race number. VPA does **not** come with a game; you get those files
  from your VGA Planets host.

### Runtime libraries
The binary uses a handful of standard X11 libraries that are already present on
virtually every Linux desktop. If it complains about a missing `lib…so`, install
them:

- **Arch:** `sudo pacman -S libx11 libxext libxfixes libxi libxrandr libxxf86vm`
- **Debian/Ubuntu:** `sudo apt install libx11-6 libxext6 libxfixes3 libxi6 libxrandr2 libxxf86vm1`
- **Fedora:** `sudo dnf install libX11 libXext libXfixes libXi libXrandr libXxf86vm`

> **Wayland:** works out of the box through **XWayland** (present in almost all
> desktops). Nothing to configure.

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
  directory is used.

Example (playing race 3, game in `~/PLANETS/mygame`):
```sh
./VPA 3 ~/PLANETS/mygame
```

Run it with no arguments to see the banner and confirm it starts:
```
$ ./VPA
-= VGA Planets Assistant 3.67  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team =-
Use: VPA race [dir] ...
```

`./VPA /?` lists all command-line options (`/B`, `/K`, `/M`, `/O`, `/P`, `/PW:pwd`,
`/R`, `/S`, `/REP:frm,rep`).

### Support files (`VPA.HLP` and `LITT_VPA.CHR`)
Keep both support files where you run VPA — in your game directory or next to the
binary:

- **`VPA.HLP`** — the built-in help. With it present, press **F1** inside VPA for
  the help screen; without it, F1 simply shows nothing.
- **`LITT_VPA.CHR`** — the small vector font used for the map labels (planet and ship
  names). If it's missing, VPA still runs but falls back to a built-in font, so those
  labels won't look quite right.

Neither file stops VPA from starting, but you'll want both for the full, correct
experience.

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
```

| `VPA_SCALE` | Result |
|---|---|
| *(unset)* | **2×** window (default). |
| `1` | Native **640×480**, the smallest. |
| `2`…`8` | **N×** window (clamped to what fits on your screen). |
| `fullscreen` | **Fullscreen** (largest 4:3 fit, above the desktop panel). Aliases: `full`, `max`. |

Fullscreen applies only to VPA's own window — it does **not** change your monitor's
resolution, and it's released when you close VPA.

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

## 5. Credits & license

VPA was written by **Alex V. Ivlev** (© 1993–96) and maintained afterwards by the
VPA team; it includes combat logic derived from **PCC2ng** by **Stefan Reuther**.
This native Linux port keeps all original copyright notices. The program is based on
the original work published on SourceForge under the **MPL** license.

If you hit a problem specific to this Linux build, note your distribution and what
you were doing when it happened.

Enjoy, and good luck out there, Commander. 🚀
