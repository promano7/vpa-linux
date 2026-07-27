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

- A **64-bit x86 Linux** system with a graphical (X11 or Wayland) session.
- The **`VPA` binary** (in this package), plus the support files shipped with it:
  **`DISTTABL.DAT`** (required — a distance table VPA needs to start), **`VPA.MSG`**
  (message templates), the **`VPA.HLP`** help file and the **`LITT_VPA.CHR`** map font.
- A **VGA Planets game directory** of your own: the folder with your turn files
  (`GENx.DAT`, `SHIPx.DAT`, `PLANETx.DAT`, `BDATAx.DAT`, `PLAYERx.RST`, etc.), where
  `x` is your race number. VPA does **not** come with a game; you get those files
  from your VGA Planets host.
- The **VGA Planets files themselves** (`PLANET.NM`, `RESOURCE.PLN`,
  `PLANETS.EXE`, the `*SPEC.DAT` files…), which are not shipped with VPA-Linux —
  see "Files not shipped with VPA-Linux" in §2.

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
-= VGA Planets Assistant 3.67.2  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team  (c) 2026 VPA-Linux Pablo Romano =-
Use: VPA race [dir] ...
```

`./VPA /?` lists all command-line options (`/B`, `/K`, `/M`, `/O`, `/P`, `/PW:pwd`,
`/R`, `/S`, `/REP:frm,rep`).

### Support files
Keep these files where you run VPA — in your game directory or next to the binary:

- **`DISTTABL.DAT`** — a precomputed distance table. **Required:** VPA refuses to
  start (and exits) if it's missing or damaged. Ship it as-is; don't edit it.
- **`VPA.MSG`** — the message templates VPA uses to parse and format incoming host
  messages. If it's missing, VPA still runs but warns and can't parse messages. It's
  a plain-text file in **Unix (LF)** line endings — keep it that way; a DOS (CRLF)
  copy won't parse correctly on Linux.
- **`VPA.HLP`** — the built-in help. With it present, press **F1** inside VPA for the
  help screen; without it, F1 simply shows nothing.
- **`LITT_VPA.CHR`** — the small vector font used for the map labels (planet and ship
  names). If it's missing, VPA still runs but falls back to a built-in font, so those
  labels won't look quite right.

Only `DISTTABL.DAT` is strictly required to start; the rest are optional but wanted
for the full, correct experience.

### Files not shipped with VPA-Linux, required to play a game

VPA-Linux is just the client: it does **not** include the VGA Planets game data nor
your game files. Those come from your original VGA Planets installation and from
your host, and they must be present for you to play.

**In the VPA directory** (next to the binary):

| File | What it's for |
|---|---|
| `PLANET.NM` | the planet names. |
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
| `RACE.NM` | the race names. |

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

If you hit a problem specific to this Linux build, note your distribution and what
you were doing when it happened.

Enjoy, and good luck out there, Commander. 🚀
