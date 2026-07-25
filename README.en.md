# VPA-Linux — Native port of VGA Planets Assistant to GNU/Linux

> 🌍 Este documento también está disponible en español: [`README.es.md`](README.es.md).

Reconstruction of the **VPA (VGA Planets Assistant)** client from its original
Turbo/Borland Pascal DOS source into a **native GNU/Linux** binary, compiled with
**Free Pascal (FPC)** and using **`ptcgraph`/`ptccrt`** as the graphics layer in
place of Borland's BGI.

- **Reference base code:** VPA 3.67 (SourceForge source).
- **Original author:** Alex V. Ivlev (1993–96); maintained afterwards by others.
- **Goal:** a native Linux executable, no DOSBox or dosemu.

> Project status: **Playable!** 🎉 The native binary loads a real game, draws the
> star map, and fully responds to the **keyboard** (F1 help, F3 messages, F5 combat
> simulator, navigation…) and the **mouse** (move, select, edge scroll). The help
> (`VPA.HLP`) renders, idle CPU usage is ~0, and the pointer behaves normally. The
> **combat simulator** and **StarBases** show ship sprites, the window is
> **resizable** and supports **fullscreen** (`VPA_SCALE`), and exiting distinguishes
> saving (**Alt-X** / the **[X]** button) from quitting without saving
> (**Ctrl-Alt-X**, with confirmation). VPA's own **white crosshair** shows as the
> cursor inside its window (only there, without affecting the rest of the desktop),
> auto-scaled to the window size.
> This document is updated as work progresses.

> **Verified environment** (FPC 3.2.2 / Ubuntu 24.04): the `ptcgraph`, `ptccrt`,
> `ptcmouse` units and the `ptc` backend are available (`fp-units-gfx` package), the
> toolchain compiles and links `ptcgraph` programs, and the resulting binary depends
> on **libX11** (it's an X11 app; on Wayland it runs via XWayland). Details in
> [§5 Development environment](#5-development-environment-verified).

---

## 1. License analysis

> 📄 **License summary and full texts: [`LICENSE.md`](LICENSE.md)** (with a copy of
> the MPL in [`MPL-2.0.txt`](MPL-2.0.txt)). In short: the **VPA** code (and its
> modifications) stays under **MPL**; the parts ported from **PCC2/PCC2ng** are under
> the *PCC II License Terms* (BSD-style); the vendored **Free Pascal** files are under
> **LGPL** with the static-linking exception; and the **new port code** is under
> **BSD 3-Clause**, © 2026 Pablo Romano Gómez. Attribution:
> *"based on original work published at <https://sourceforge.net/projects/vpa/> under the MPL license"*.
> This section keeps the detailed analysis that led to that decision.

> **Project intent (port author's decision):** this port will be **free, open-source
> software**, free of charge, for the whole VGA Planets community, published on
> **GitHub**. Using **GPL** dependencies or references is acceptable without issue if
> they're the best technical choice. The licensing goal is therefore a free license
> **compatible with GPL** (presumably **GPL v2 or later** itself, which is compatible
> with the PDK and with `ptcgraph`/FPC). The requirement is simple: **make the final
> license clear and keep all copyright notices** from every author (original VPA,
> PHOST/PDK, PCC2…) once the repo goes public.

Before considering redistribution, it's worth being clear on the actual licensing
situation, because **what SourceForge's project page says doesn't match what the
code says**.

### What SourceForge says
The project page declares **Mozilla Public License 1.1 (MPL 1.1)**.

### What the source code actually says
After reviewing the whole tree (versions 3.63 and 3.67):

- **There is no `LICENSE` or `COPYING` file** in the package.
- **There are no MPL license headers** in the `.pas` files.
- The string "Mozilla" or "MPL" **does not appear even once** anywhere in the code.
- The MPL 1.1 tag therefore lives **only as a SourceForge project metadata field**,
  not as an explicit grant written by the authors in the files.

The authorship that *is* declared in the code is **layered**:

| Part | Declared authorship | Notes |
|---|---|---|
| VPA core | Alex V. Ivlev, "Copyright (c) 1993-96" | The base of the program |
| Later maintenance | Screens "Copyright (c) 1998" and "(c) 2003" | Successive maintainers |
| `CC/` (PCC code) | Stefan Reuther | Terms in `CC/README` and §1 (PCC2/PDK). Kept in the build. |
| ~~DPMI subsystem~~ (removed) | Stefan Reuther (D4TP, © 2000-02) | **Removed from the port** along with its license `UNIT/DPMI.TXT` (it was DOS-only). |
| Bundled documentation | Dave Killingsworth (Starbase), Unity… | Docs only, no code |

### What this means in practice

**For personal use and porting:** no problem. The project is publicly offered as
free software, and modifying for personal use a program obtained legally poses no
conflict. It can be ported comfortably.

**For public redistribution:** a prior step is worthwhile. MPL 1.1 is perfectly
suited for this goal (it allows modified versions; it's a *weak, file-level
copyleft*; it's compatible with linking against FPC/`ptcgraph`). The nuance is that
here the MPL 1.1 is **the current maintainer's stated intent, not a grant written
into the files by each historical author**. With several authors and no explicit
grant in the code, the clean approach is:

1. **Situation clarified with Stefan Reuther (PCC/PDK).** When asked about the
   absence of `LICENSE`/`COPYING` in the package, he confirmed there **never was
   one**: as far as he can see in the SourceForge git history, Alex Ivlev handed the
   code to Alexander Babanov (`lastberserker`), who uploaded it to SourceForge; the
   **MPL** tag lives only as project metadata. His recommendation ahead of
   publishing: add a `README` pointing to the original repository ("*based on
   original work published at &lt;link&gt; under MPL license*") and a `LICENSE` file
   with the **MPL** (or a compatible one). This is the plan for closing out the
   license before publishing (Phase 7).
2. For the **Stefan Reuther** code that's kept (`CC/`, PCC), the terms are in
   `CC/README` and in §1 (PCC2/PDK). Its **DPMI subsystem** (D4TP) has been
   **removed** from the port (it was DOS-only), and with it its license
   `UNIT/DPMI.TXT`. He's still active in the VGA Planets community (PCC2, c2ng…) in
   case he needs to be consulted.
3. Keep all copyright notices (Ivlev, Reuther and the rest) in the derived version.

> **Note on MPL 1.1 + GPL:** MPL 1.1 by itself is considered incompatible with GPL.
> This **does not affect** this port: the FPC RTL and `ptcgraph` are under a
> *modified LGPL* (with a linking exception), which imposes no GPL-style
> obligations. It would only matter if strictly GPL code were incorporated in the
> future.

### External reference sources (PCC2 / PDK)

For the hull-functions logic, Stefan Reuther's code is available as a
**reference**. (Note: the `CC/HULLFUNC.PAS` shipped with the source is actually
the **PCC** unit —Streu, 2005-06—, with dependencies missing from the PCC 1.x
ecosystem; **VPA implements its own version** —the *old* model— in `VPADATA.PAS`.)
Reuther's sources are C/C++, they **contain no drop-in Pascal units**, but they
document the logic and data format for reference:

| Source | Useful content | License |
|---|---|---|
| **PCC2** (`pcc-v2`, 2025) | `game/hullfunc.cc/.h` (hull-functions logic in C++) | **BSD-style permissive** ("PCC II License Terms": keep copyright, mark modifications). © 2001-2024 Stefan Reuther & contributors. **Not GPL.** |
| **PDK** (`pdk`, 2010) | `hullfunc.c`, `pconfig.c` (`hullHasSpecial`, `HullDoesAlchemy`, `HullCanHyperwarp`…) | **GPL v2 or later.** © 1995-2000 Andrew Sterian, Thomas Voigt, Steffen Pietsch (+ M. van Rees, S. Reuther). |
| **PCC2ng** (`c2ng`, 2025) | `game/vcr/classic/pvcralgorithm.cpp` (**PHost** combat algorithm and its `Visualizer` interface) — base of the native combat viewer (see §7) | **BSD-style permissive** (*PCC II License Terms*). © Stefan Reuther & contributors. **Not GPL.** |
| **cpluslib** (2025) | C++ utilities (container templates) | **Public domain.** |

**License implication (in light of the project's intent):** since the port will be
free and **GPL** is acceptable, **both sources can be used**. The **PDK**
(`hullfunc.c`, GPL v2+) could even be used as a direct translation base; if so, that
portion —and by contagion the combined result— would end up **GPL**, which is
consistent with the goal (publishing under a GPL-compatible free license). **PCC2**
(BSD-style permissive) remains the more flexible option (compatible with any final
license) and tends to be a more readable/modern C++ reference. Either way, the
**copyright notices** of the authors are kept (PHOST/PDK: Sterian, Voigt, Pietsch,
van Rees, Reuther; PCC2: Reuther). Practical reminder: the logic of "which hull has
which ability" is largely determined by the game's data (`hullfunc.txt`,
`shiplist.txt`, `auxdata.hst`), whose **format is fact** and not protectable
material.

**Status (resolved, PDK not translated):** using the PDK as a translation base was
evaluated, but turned out to be **unnecessary** for VPA's data model. VPA doesn't
use PHost's modern hull-functions model (the one `hullfunc.c` in the PDK operates
on), but rather the **old model**: a `HullFunc^` array with functions 0..19 loaded
in `CONFIG.PAS` (from `DefaultHullFunc` plus the host's settings). For that model,
the existing `IsHullFunc` function is already the equivalent of the PDK's
`hullHasSpecial`. That's why `IsShipFunc3` and `ShipOrHullDoes` were implemented
(they were *stubbed* to `False`, disabling detection of **fleet chunneling** and
**advanced cloaking**) by **bridging** the `SPC_*` codes to the old model: `SPC_*`
0..19 match the ordinal of `HullFuncs`; the ones ≥20 (ChunnelSelf/Others/Target,
HardenedCloak…) are PHost refinements that the old model groups into
`hfChunneling`/`hfCloak`, and are ignored without real loss for this model. The PDK
was used to **confirm** the `SPC_*` numbering and the "ship-or-hull" semantics, but
none of its code was translated.

The PCC2-style `Enum*` layer (`EnumHullfuncsForShip`, e.g. the detail screen with
the ship's **full list** of abilities) remains **only** under `{$IFDEF VPACC}`,
which is **disabled**; porting it would require the modern model (PDK/PCC2) and the
`hullfunc.txt`/`shiplist.txt` data — it remains **pending and optional**.

### Vendored Free Pascal files (`VENDOR/`)

To offer an **optional larger window** (`VPA_SCALE` variable) without risky video
mode changes or window-manager "fullscreen", the port includes in `VENDOR/` a copy
of several **Free Pascal** files and **applies a minimal patch** to one of them:

| File | Status | What it's for |
|---|---|---|
| `ptcgraph.pp` | **Modified** (VPA patch) | Reads the scale (`VPAForceScale`/`VPA_SCALE`) and creates `ptc`'s "console" larger while keeping the surface at 640×480; `ptc` scales it. Also carries `{$mode objfpc}` and `sysutils` to compile within VPA's build. The header includes a **visible modification notice** (required by the LGPL). |
| `ptcmouse.pp` | **Unmodified** | Needed to self-containedly recompile `ptcgraph` (FPC rebuilds it against the patched `ptcgraph`, avoiding a `.ppu` version mismatch). |
| `ptccrt.pp` | **Modified** (VPA patch) | Base for self-contained recompilation of `ptcgraph`, and also carries several VPA patches in keyboard handling: exposes `PTCLastKbdFlags` (Shift/Ctrl/Alt of the last event, used as a fallback), treats the window's **[X]** button as **Alt-X** (quit saving) and sets `PTCQuitNoSave` for **Ctrl-Alt-X** (quit without saving), and emits **Alt+arrow** (`$9B/$9D/$98/$A0`) also in `kmTP7` mode —VPA's— not just in `kmGO32/kmFPWINCRT` (restores DOS TP7 behaviour). With its modification notice. |
| `ptc/` (`core/` + `x11/`, ~556 KB) | **2 modified files** (`x11/x11extensions.inc`, `x11/x11windowdisplayi.inc` + its `.d.inc`) | The backend under `ptcgraph`. Vendored to rebuild it **without the X11 DGA extensions** (`x11extensions.inc`: only the two `{$DEFINE …XF86DGA1/2}` are commented out) so the binary doesn't depend on `libXxf86dga` (dropped by Arch). Also, `x11windowdisplayi.inc`/`.d.inc` carry **VPA's white crosshair as the window's cursor** (symmetric cross, auto-scaled, per-window; see §7 "Current status (runtime)" item 13). All changes carry a modification notice; the rest ships intact. The `Makefile` (`ptc` target) rebuilds it into `build/ptcunits/`. |
| `graphh.inc`, `graph.inc`, `clip.inc`, `fills.inc`, `fontdata.inc`, `gtext.inc`, `modes.inc`, `palette.inc` | **Unmodified** | Includes pulled in by `ptcgraph`. |

**License of these files:** they're part of the **Free Pascal run-time library**,
under the **modified LGPL with the static-linking exception** (the same one FPC
ships under). **All copyright headers** are kept intact (Nikolay Nikolov, Daniel
Mantione and the FPC team). The modified files —`ptcgraph.pp` and
`ptc/x11/x11extensions.inc`— carry a modification notice in their header, as the
LGPL requires.

**Why it doesn't break the licensing goal:** the LGPL (with the linking exception)
is **compatible with GPL**: these files can be combined and redistributed within a
project that as a whole is GPL. Vendoring copies (instead of only linking against
the system's FPC) is legitimate under the LGPL as long as —as done here— notices
are kept and changes are marked. In practice:

- The parts that are **the port's own** (translated/adapted VPA code,
  `UNIT/xfocus.pas`, fixes…) fall under the **free license chosen for the port**
  (GPL-compatible).
- The files in `VENDOR/` **remain under their original modified LGPL**; they aren't
  relicensed.
- The final binary links against `libX11`/FPC, all under compatible free licenses.

> If you'd rather **not vendor** them: just delete `VENDOR/` and remove `-FuVENDOR`/
> `-FiVENDOR` from `vpa.cfg`. The port goes back to linking against the system's
> `ptcgraph` and the window stays fixed at 640×480 (only the `VPA_SCALE` option is
> lost).

*Notice: this analysis is informational, not legal advice.*

---

## 2. Analysis of the base code

Real metrics measured on the **3.67** source (`.pas` files only):

| Module | Files | Lines | Role | Fate in the port |
|---|---:|---:|---|---|
| `VPA/` | 26 | 40,390 | Application core | **Migrate** |
| `VPAMM/` | 11 | 8,349 | "Mixed mode": DPMI + VESA + custom kernel | **Dropped (removed from the repo)** |
| `UNIT/` | 11 | 3,293 | Low-level layer (mouse, keyboard, DPMI…) | **Partially rewrite** |
| `CC/` | 5 | 4,149 | PCC code (PHost command messages), optional | Optional (`$IFDEF VPACC`) |
| `VHLP/` | 3 | 324 | Help system | Migrate (simple) |
| **Total** | **56** | **56,505** | | |

### Where the difficulty is concentrated

The key finding of the analysis: **the DOS-dependent code is concentrated exactly
where it hurts least**.

| Dependency | VPAMM (dropped) | UNIT (rewrite) | VPA core | CC |
|---|---:|---:|---:|---:|
| Interrupts (INT/Intr/MsDos) | 89 | 44 | 11 | 8 |
| Inline assembly lines | 137 | 90 | 29 | 10 |
| `absolute`/`Mem`/`Port`/`Seg`/`Ofs` | 67 | 89 | 146 | 7 |

- **Dropping VPAMM** removes at a stroke most of the asm and interrupts.
- The bulk of the rest is in `UNIT/MOUSE.PAS` and `UNIT/KEYBOARD.PAS`, rewritten
  **once**.
- The core (40,000 lines) ends up nearly clean: 11 interrupts and 29 lines of asm
  across 10 files.
- Note: many of the core's 146 `absolute` uses are **variable aliasing** (portable),
  not hardware access. They need to be told apart case by case.

### What must be replaced no matter what (binaries that can't be recompiled)

| File | What it is | Replacement |
|---|---|---|
| `VPA/SVGA.OBJ` | SVGA BGI driver by U. von Bassewitz (256-colour VESA) | `ptcgraph` |
| `VPA/GREETS.ASM` | 16-bit TASM assembly | Rewrite in Pascal or drop |
| `VPAMM/SANSFONT.OBJ`, `VPAMM/PROPFONT.OBJ` | Mixed-mode fonts | N/A (VPAMM dropped) |
| `*.bgi` (egavga) | Borland BGI driver (external link) | `ptcgraph` |

### The decisive point in its favour

The application draws **through the standard BGI API** (~2,400 calls like
`InitGraph`, `Line`, `OutTextXY`, `SetFillStyle`…). `ptcgraph` reimplements that API
as an almost *drop-in* replacement. What's more, the project **already abstracted
its graphics layer once before** (`VPAMM/GRAPH.PAS` reimplements the `Graph`
interface over a different kernel), which shows the code only depends on the API's
*surface*, not its internals.

> **Why `ptcgraph` and not SDL:** `ptcgraph` keeps the BGI API, so the ~2,400 calls
> keep working almost untouched. `sdlgraph` has been reported broken for years by
> the FPC team itself. SDL remains valid as a *second phase* of real modernisation,
> but as an initial migration path it would force a full manual rewrite.

---

## 3. Overall strategy

1. **Don't port everything.** Drop the entire VPAMM/DPMI subsystem: it solved a
   problem (DOS memory limits) that doesn't exist on native Linux.
2. **Preserve the graphics layer via `ptcgraph`** instead of rewriting it.
3. **Start with 640×480 / 16-colour mode**, the most solid one in `ptcgraph`;
   evaluate 256 colours afterwards.
4. **Incremental migration** with git: each phase is a set of reviewable commits
   and, where possible, a compilable state.
5. **Goal of the early phases:** get something equivalent to the original starting
   up as soon as possible, then polish.

---

## 4. Step-by-step migration plan

Each task is checked off as completed. The phases aim to leave the tree in a
verifiable state at the end of each one.

### Phase 0 — Environment setup
- [x] Install Free Pascal and verify it includes `ptcgraph`, `ptccrt`, `ptcmouse`, `ptc`. ✅ FPC **3.2.2**; units in the `fp-units-gfx` package. Toolchain compiles and links. *(See §5.)*
- [x] Initialize the git repository and import 3.67 **intact** as the reference base. ✅ Done: uploaded in the 3rd commit (`Updated README.md and uploads original source code`); the first two commits were the initial README and its update.
- [x] Working branch. ✅ Development happens on **`main`**. Once the first native binary ships, the state will be **frozen** as branch **`3.67`** (release) and `main` will continue as the development branch for future fixes and improvements.
- [x] Add `.gitignore`, `.gitattributes` and `setup-env.sh` (deliverables of this phase, already generated).
- [x] Resolve/note the license question (contact the maintainer if distribution is planned). ✅ **Noted and contacted**: the full analysis is in §1, and **Stefan Reuther** (PCC/PDK) was consulted, confirming there was never a `LICENSE`/`COPYING` in the package —only the **MPL** metadata on SourceForge— and recommending, ahead of publishing, adding a `README` pointing to the original repository ("based on original work published at &lt;link&gt; under MPL license") and a `LICENSE` file with the MPL (or a compatible one). The actual close-out (adding the `LICENSE`) is left for right before publishing (see Phase 7).
- [x] Convert CRLF→LF line endings (handled by `.gitattributes`) and document the text encoding.

### Phase 1 — Trimming and build scaffolding
- [x] **VPAMM is already disabled** by default (`{.$DEFINE VPAMM}` in `switches.inc`): the standard `vpa.pas` build doesn't include it. No need to touch the core to drop it.
- [x] **`VPAMM/` folder dropped and removed from the repository.** It was DOS's "mixed mode" variant (DPMI + VESA + its own graphics kernel: `DRIVERS`, `AAVESA`, `AAFONT`, `VESA256`, `VGA640`, `GRAPH`…). The `VPAMM` symbol is never defined in the port (the `{$IFDEF VPAMM}` blocks compile to nothing) and the graphics layer is `ptcgraph`, not those drivers. Verified that `vpa.pas` **compiles and links without the folder** (it's not in `vpa.cfg`'s `-Fu` paths nor used by any `uses`/`{$I}` in the live build). The DPMI units in `UNIT/` (`DPMI`, `DPMITEST`, `MEMTEST`, `SYSEXT`) are only used by dropped test programs; pending separate removal (see Phase 4).
- [x] `vpa.cfg` for FPC in `{$MODE TP}` with the project's unit paths + ptcgraph (Arch path verified). *(Replaces `BPC.CFG`.)*
- [x] **`Makefile` for FPC** (replaces the Borland Make one): `build`/`clean`/`run`/`help` targets. Build with `fpc @vpa.cfg VPA/VPA.PAS`. Full build and run instructions in **[`BUILD.es.md`](BUILD.es.md)** (or in English, **[`BUILD.en.md`](BUILD.en.md)**) (Arch dependencies, running a game, troubleshooting).
- [x] Decide on `VPACC` and `TASKS`: **both stay OFF** (commented out in `switches.inc`). The `VPACC` layer (PCC2-style `Enum*`) is not enabled to reduce surface area; the features that depended on it (hull-functions: fleet chunneling, advanced cloaking…) were resolved on the **old model** (`IsShipFunc3`/`ShipOrHullDoes`, see §1), with no need to turn `VPACC` on.
- [x] **Global cleanup of Borland directives** with no Linux equivalent: `{$C MOVEABLE PRELOAD PERMANENT}` (DOS segment/overlay attributes), etc. — mass strip.
- [x] First test compile (bottom-up, starting with a leaf unit like `STRF`): **collect the list of real errors**.

### Phase 2 — Graphics layer (`ptcgraph`)
- [x] **Verified: `ptcgraph` covers 100% of the BGI API VPA uses** (tested by compiling a program with every call: `Line`, `OutTextXY`, `GetImage`/`PutImage`, `Circle`, `Bar`, palettes, viewports…). It's practically *drop-in*.
- [x] **`swapgraph.py`**: changes `uses Graph`→`ptcgraph` (and `Crt`→`ptccrt`) in the `uses` clauses of the 22 affected files, preserving encoding. (VPA doesn't use `Crt`; it does use `Dos` in 5 files → Phase 4.)
- [x] Apply `swapgraph.py` to the files with `uses Graph`.
- [x] **Rewrite `VPA/VPAINIT.PAS`'s init**: the SVGA/CustomBGI/EGAVGA branches register external BGI drivers (`@svgaProc`, `@EGAVGADriverProc`, `@SmallFontProc`) that don't link on Linux. In ptcgraph, `InstallUserDriver`/`RegisterBGIDriver` are no-ops; the whole block is replaced with a direct `InitGraph(gd,gm,'')` call with a native mode (e.g. `gd:=D8bit; gm:=m640x480` for 256 colours). Remove `SVGA.PAS`/`SVGA.OBJ`.
- [x] Rewrite `GREETS.ASM` in Pascal or drop it. ✅ **Dropped**: `WriteGreeting` (`VPAEXIT.PAS`) uses a stub with no greeting data, `GREETS.OBJ` isn't linked, and `GREETS.ASM`/`GREETS.BAT` remain as dead files (not compiled or referenced).
- [x] Port the graphics core chain (`SCREEN`, `VPADATA`, `Global`…) until it compiles.
- [x] **Milestone:** start up in graphics mode and draw the star map.
- [x] **Optional larger window (`VPA_SCALE`).** The drawing surface stays at 640×480 (all of VPA's UI is designed for that size); to enlarge the window without changing the video mode or using the window manager's "fullscreen" (both caused hangs), a **`ptcgraph` with a minimal patch is vendored**, creating a larger `ptc` "console" and letting `ptc` scale the 640×480 surface to fill it (see `VENDOR/` and §1). The mouse is rescaled both ways (`xfocus.MapMouseToSurface`/`MapSurfaceToWindow`) so clicks and arrows keep pixel-perfect precision. Options (environment variable):
  - unset → **2× scale by default** (windowed on the desktop);
  - `VPA_SCALE=1` → native 640×480 (unscaled);
  - `VPA_SCALE=N` (2…8) → N× window (clamped to what fits on screen), always **windowed** on the desktop;
  - `VPA_SCALE=fullscreen` → **real fullscreen**: uses the largest 4:3 fit (same pixel count as the equivalent `N`, crisp) and asks the window manager for `_NET_WM_STATE_FULLSCREEN`, so the window sits **above the desktop panel** (fixes downward scroll on desktops with a bottom panel). The leftover 16:9 areas sit on the sides (4:3). Exits the same way, with **Alt-X**. It's safe and recoverable: fullscreen is applied to **VPA's own window** (it doesn't change the monitor's video mode) and is explicitly released on close, so the panel reappears.
    - The window is **enlarged to fill the screen** (some window managers only hide the panel if the window covers the whole monitor); since `ptc` paints its content in the top-left corner, the 4:3 content stays pinned to the left with a black strip on the right (it shows complete and undistorted).

### Phase 3 — Input: mouse and keyboard
- [x] Rewrote `UNIT/MOUSE.PAS` over `ptcmouse` (event polling with `PollMouse`) instead of INT 33h + an asm handler. Detects edges (move, press/release of each button) by comparing previous/current state and dispatches to `HandlerTable`.
- [x] Rewrote `UNIT/KEYBOARD.PAS` over `ptccrt` (`ReadKey`, `KeyPressed`, `PreviewKey`).
- [x] **Mapped the BIOS scancodes** ($3B00=F1, etc.): `ReadKey` returns the ascii in the low byte or the scancode in the high byte for extended keys.
- [x] **`PollMouse` wired into the input loop:** called from `KeyPressed` (not `FastKeyPressed`, reserved for animation loops). Chain verified: main loop → `KeyPressed` → `PollMouse` → `Dispatch(EvLtPress…)` → `MouseHandler` sets `mEvent` → the `while mEvent<>0` block runs the action. Compiles, links, and starts.
- [x] **Interactive test** (with a real game): navigating map and menus with the mouse — **validated by playing** (map, planets, StarBases, combat…). **Shift/Ctrl/Alt: resolved** — `KbdFlags` queries the current modifier state from X11 (`XQueryPointer`, BIOS-`0040:0017` style), validated by injection (Shift→3, Ctrl→4, Alt→8) both for keyboard shortcuts and mouse+modifier (map zoom).
- [x] **Milestone:** navigate the map and menus with mouse and keyboard.

### Phase 4 — Low-level cleanup (UNIT + core)
- [x] **Removed** `UNIT/DPMI.PAS`, `UNIT/DPMITEST.PAS`, `UNIT/MEMTEST.PAS`, `UNIT/SYSEXT.PAS` (DOS's DPMI subsystem), plus the dead DOS binaries `UNIT/DPMI.TPU`/`UNIT/SYSEXT.TPU` and the `UNIT/DPMI.TXT` doc/license. Verified nothing live uses them and that `vpa.pas` compiles and links without them. `DPMI` was only used by `DPMITEST`/`MEMTEST` (test programs, also dropped).
- [x] Review `UNIT/AUXF.PAS` and `UNIT/STRF.PAS`: replace asm with Pascal/FPC intrinsics. ✅ **Done** (during the initial port of these leaf units). Both files are **100% Pascal**, without a single line of assembly: `AUXF` uses FPC intrinsics (`CompareByte` in `Diff`, `Sleep` in `Delay`, `GetTickCount64` in `Timer`, `SysUtils`) and `STRF` rewrote the x86-asm routines (`ItemPos`/`ItemStr`, originally `repne scasb`) in pure, portable Pascal. Verified functionally.
- [x] Handle the core's ~11 interrupts and ~29 lines of asm, file by file (system time, etc.). ✅ **Done.** Exhaustive sweep of the core (excluding comments and `(* *)` blocks): **zero live interrupts** (`Intr`/`MsDos`/`Registers`), **zero ports** (`Port[`), **zero DOS memory** (`Mem[`/`Seg0040`), and **zero live asm**. The "~11/~29" figures were from the analysis of the original 3.67 (§2); they were resolved during the port — rewritten in Pascal (documented by "original asm" comments in `MESSAGES`/`VPA2`/`VPAINIT`) or left as dead, commented-out code (the two asm blocks in `SCRSAVER.PAS`, disabled screensaver effects). The binary compiling and linking on x86-64 confirms it: the 16-bit asm or DOS interrupts wouldn't even compile.
- [x] Classify the core's `absolute` uses: *aliasing* (kept) vs. hardware access (rewritten). ✅ **Done** (audit): of the **142** live `absolute` uses in the core, **all 142 are variable aliasing** (portable type-punning: `ls:byte absolute s` for a string's length byte; `SRec/PRec/MRec absolute b` to reinterpret a buffer as different records — union idiom). **Zero** of the hardware form (`absolute segment:offset` or a numeric address), consistent with it compiling on x86-64 (that form wouldn't even compile). They're portable for the little-endian target; unpacking records read from disk is already covered by `{$PACKRECORDS 1}` and the endianness note in Phase 5.

### Phase 5 — File I/O and data portability *(critical)*
- [x] **Type sizes** *(verified in §5)*: under `{$MODE TP}` with FPC 3.2.2 x86_64, `Integer`=2, `Word`=2, `LongInt`=4 bytes (identical to BP7). **Two confirmed pitfalls:** `Pointer`=8 bytes (was 4) and `Real`=8 bytes (in BP7 it was **6 bytes**). **Resolved:** the records that go to disk (`SRec`, `STRec`, `MRec`, `URec`, combat…) only contain `int`/`char`/`long`/`byte`/`boolean` — **no `pointer` or `real` inside** (audited), so there's no size mismatch. The one problematic `Pointer`→integer conversion was in the error-address display (`VPA.PAS`, error handler); fixed with `PtrUInt`.
- [x] **Record packing (CRITICAL, resolved).** Turbo/Borland Pascal **always** packs records with no padding; FPC in TP mode **aligns to 2 by default**, inserting padding after odd-sized fields (e.g. `fcode`, 3 bytes, in `SRec`) and misaligning what's read from the `.DAT` files. Verified: `SizeOf(SRec)`=124 with padding vs. **123 byte-packed** (`name` at offset 46 vs 45). Fix: `{$PACKRECORDS 1}` in `switches.inc` (included by every unit) → layout identical to DOS. Binary recompiles, links, and starts.
- [x] **`VPAx.DB` header (RESOLVED, bug found in real gameplay).** `VPAEXIT.PAS`
  wrote the header with `BlockWrite(f,DBHeader,DBHeadLen)`, where `DBHeader` is a
  **14**-byte array but `DBHeadLen`**=15** — it reads 1 byte **past** the array
  (undefined behaviour). On Borland Pascal/DOS that "extra" byte happened, by
  coincidence of the constant segment's memory layout, to match `DBVersion`
  (declared right after); with FPC on Linux the layout is different and that byte
  comes out as `0`, so the `.DB` was created with an invalid header and the
  **next** run failed with `ERROR: Unknown version of VPA database`
  (`VPADATA.PAS`, version check). Reproduced in isolation (byte 15 = 0 instead of
  6) and fixed by writing the header (14 bytes) and the version (1 byte) as two
  well-delimited `BlockWrite` calls, without depending on memory layout.
  **Update note:** a `VPAx.DB` already created by a binary with the bug is left
  with an invalid header and needs to be deleted once (it regenerates itself on
  the next start); it doesn't affect the game's `.RST`/`.TRN`.
- [x] **Endianness (validated + guard).** VGA Planets files (`.DAT`/`.RST`/`.TRN`/`VPAx.DB`) are **little-endian** (DOS x86 format) and VPA reads/writes them raw with `BlockRead`/`BlockWrite` over packed records, with no conversion. This is correct on **every realistic Linux target** (x86-64, ARM64, ARM32, RISC-V… all little-endian by default), so **it works on ARM the same as on x86**. To avoid silently corrupting data on a hypothetical **big-endian** target (which would need byte-swapping, not implemented), a **compile-time guard** was added in `switches.inc`: `{$IFDEF ENDIAN_BIG}{$FATAL …}{$ENDIF}` — inert on little-endian, and on big-endian it **aborts compilation with a clear message** instead of producing a binary that would corrupt games. Verified the guard is inert on x86-64 and that it fires correctly (tested by flipping the condition).
- [x] **DOS→Linux path separator (RESOLVED).** `OpenRW`/`OpenData` prepend the game directory (`addir`) to every file name, and `VPAINIT` used to append a DOS `\` → `LUPUS4\GEN5.DAT` doesn't exist on Linux. Changed to `/`. (`OpenData` already tries `addir+name` and falls back to `name` in the current directory, so master files like `PLANET.NM` are found fine.)
- [x] **Runtime checks (RESOLVED).** The original `BPC.CFG` globally disabled I/O, range, overflow and stack checks (`/$I-,R-,S-,Q-`); the code assumes `{$I-}` (checks `IOResult` after `Reset`, no exceptions). Without this, a missing file threw `EInOutError 217` at startup. Replicated in `vpa.cfg` with `-Ci- -Cr- -Co- -Ct-` (applies to every unit, including ones that don't include `switches.inc`, like `INI`). Verified: the binary starts, writes its config, and reads the game data from the given directory.
- [x] **Uppercase/lowercase paths (RESOLVED).** Real games mix upper and lower
  case (e.g. PHOENIX4 ships `GEN7.DAT` in uppercase but `pconfig.src`,
  `beamspec.dat`, `torpspec.dat`, `race.nm`… in lowercase). VPA built file names
  in uppercase, and on a case-sensitive filesystem it **couldn't open** that data
  → it fell back to defaults (including `AllowAlternativeCombat=No`!), altering
  combat. Fix: `ResolveCase` in `CONFIG.PAS` and `VPADATA.PAS` (resolves the real
  name by scanning the directory case-insensitively); applied in
  `ReadConfigFile`, `OpenData`, `Exists`, `OpenRW` and `OpenText` (the generic
  text reader), and in the distributed config reads (`RACES.INI`,
  `MISSION.INI`, `VPADATA.INI`, `VPACLR.INI`). 8.3 names (`GEN5.DAT`…) aren't a
  problem on Linux; VPA's own `vpa.ini` is left without `ResolveCase` (consistent
  case when created/read; wrapping it would risk a read-resolved/write-original
  asymmetry when renaming).
- [x] Adapt Borland's error handling (`ExitProc`, `ExitCode`, `ErrorAddr`, `far` procedures) to FPC's equivalent.

### Phase 6 — First native binary
- [x] **Iterate until reaching a clean build and a binary that starts.** ✅ **MILESTONE: every unit compiles and links into a 64-bit ELF binary.** Starts under X11 (tested with Xvfb): initializes `cthreads`, opens the display, prints the banner and usage help, and exits cleanly when given no race/directory. `34064` lines compiled, 25 warnings.
- [x] **Range and pointer warnings fixed:** the byte-range-out-of-bounds constants came from the VPACC-off path, never compiled in the original — `VPA4` (`chr($5300)` for the DEL key, truncated to `chr(0)` as on DOS) → made explicit as `chr(0)`; `CONFIG` (`byte(key)-byte(kFF1)+1` with an enum spanning 256) → `ord(...)`. The 64-bit pointer truncation in the error display (`VPA.PAS`, `long(ErrorAddr)`) → `PtrUInt`. Only benign FPC warnings remain (ignored `$E/$L/$N` switches, some always-true/false comparisons, an uninitialized variable here and there) with no impact.
- [x] **`PollMouse` wired into the main input loop** (via `KeyPressed`; see Phase 3).
- [x] Test with real game data (RST/TRN) — needs a game directory with `GENx.DAT`, `SHIPx.DAT`, etc.

### Phase 7 — Testing, packaging and (optional) distribution
- [ ] Compare behaviour against the DOS version under DOSBox.
- [x] **Package (binary + support files: `vpa.hlp`, `vpa.msg`, resources).** ✅
  Assembled and tested a real package (`vpa-linux-3.67.1-x86_64.tar.gz`): binary +
  `VPA.HLP` (generated with `make hlp`) + `LITT_VPA.CHR` + `DISTTABL.DAT` +
  `VPA.MSG` + `LICENSE.md`/`MPL-2.0.txt` + `HOWTO.es.md`/`HOWTO.en.md`. Tested the
  way a real user would: extracted into a clean directory, `chmod +x`, starting
  with no arguments (correct `3.67.1` banner, `ldd` clean of `libXxf86dga` and any
  missing libs), `/?` showing the full help, and `VPA_SCALE`
  (`1`/`2`/`3`/`fullscreen`) all starting fine. **Packaging bug found and fixed
  along the way:** the `Makefile`'s `data` target copied `LITT_VPA.CHR` from
  `VPA/` instead of the repo root (where it actually lives), so `make data`
  wasn't including it — fixed in both places it appears in the `Makefile`
  (`build`/`data`).
- [x] Close out the license question if published. ✅ **Closed and published**:
  `LICENSE.md` (multi-license breakdown per component, all copyright notices) and
  `MPL-2.0.txt` (full text) are in the repo. See §1.
- [x] *(Optional, later phase)* Evaluate 256 colours / higher resolutions, or an SDL backend for real modernisation. ✅ **256 colours done** (the port runs in `D8bit`/m640x480, 256 colours) and **higher resolutions done** via `VPA_SCALE` (N× window and fullscreen, keeping the 640×480 surface). An **SDL backend** remains a **future optional** item (not needed: `ptcgraph` covers the BGI API; `sdlgraph` is reported broken by FPC).
- [x] **Removed the `libXxf86dga` dependency.** The `ptc` backend (`core/` + `x11/` only, ~556 KB) is vendored in `VENDOR/ptc/` with the X11 `XF86DGA1`/`XF86DGA2` extensions disabled in `x11/x11extensions.inc`; the `Makefile` (`ptc` target) rebuilds it into `build/ptcunits/` and `vpa.cfg` puts it ahead of the system's `ptc`. Verified with `ldd`: the binary no longer links `libXxf86dga` (VPA always uses the windowed X11 console, never DGA, so nothing is lost).

---

## 5. Development environment (verified)

Effectively verified on FPC **3.2.2** on Ubuntu 24.04 (x86_64).

### Required software
- **Free Pascal 3.2.2** (`fpc` package).
- **Graphics units** (`fp-units-gfx` package → pulls in `fp-units-gfx-3.2.2`):
  `ptcgraph`, `ptccrt`, `ptcmouse` and the `ptc` backend. On Ubuntu these install
  into `/usr/lib/x86_64-linux-gnu/fpc/3.2.2/units/x86_64-linux/graph/`.
  On **Arch Linux** these units ship **inside the `fpc` package itself** (no
  separate package), in `/usr/lib/fpc/<version>/units/x86_64-linux/graph/`; just
  `sudo pacman -S --needed fpc libx11`.
- At runtime the binary depends on **libX11** (an X11 app; on Wayland it runs via
  XWayland, normally already present).
- **Link-time (X) and `gcc` dependencies:** when linking, FPC passes `-lX11 -lXext
  -lXfixes -lXi -lXrandr -lXxf86vm` (no longer `-lXxf86dga`, see the Arch note
  below) and needs `gcc`'s `crt*.o` objects. On minimal distros (Arch) these need
  to be installed explicitly.
- **`libXxf86dga` (RESOLVED).** Arch **dropped `libxxf86dga`** from the official
  repos in 2019 (an Xorg cleanup), but FPC 3.2.2's `ptc` linked it for the X11 DGA
  extensions. **No extra package is needed anymore**: the port **vendors `ptc`
  without DGA** (see §1 and Phase 7) — the `Makefile` rebuilds it with
  `XF86DGA1`/`DGA2` disabled, and the resulting binary doesn't link `libXxf86dga`.
  (The old workaround of installing it from the Arch Linux Archive is no longer
  needed.)

> **Note:** on Linux there's **no** Borland `graph` unit; `ptcgraph` *is* the
> BGI-compatible replacement. When migrating, `uses Graph` becomes
> `uses ptcgraph, ptccrt`.

### Type sizes under `{$MODE TP}` (relevant for reading the `.dat` files)

| Type | BP7 (DOS) | FPC 3.2.2 `{$MODE TP}` | Match? |
|---|---|---|---|
| `Integer` | 2 bytes | 2 bytes | ✅ |
| `Word` | 2 bytes | 2 bytes | ✅ |
| `LongInt` | 4 bytes | 4 bytes | ✅ |
| `Boolean` | 1 byte | 1 byte | ✅ |
| `packed record` (ints/bytes/chars) | — | serializes the same | ✅ |
| `Pointer` | 4 bytes | **8 bytes** | ⚠️ |
| `Real` | **6 bytes** (48-bit software real) | **8 bytes** (double) | ⚠️ |

Integers and `packed` records —how VGA Planets stores almost everything— are
byte-for-byte compatible. Watch out for structures that embed **pointers** or
**`Real`** if they ever get written to disk (checked in Phase 5).

### Phase 0 deliverables (in this repository)
- `setup-env.sh` — installs and verifies the environment (FPC + graphics units +
  a test compile).
- `.gitignore` — ignores FPC build artifacts and Borland leftovers.
- `.gitattributes` — normalizes CRLF→LF line endings and flags binaries.

### Steps for the user (on your machine)
```bash
# 1. Verify/install the environment
bash setup-env.sh

# 2. Initialize the repository with 3.67 intact
git init
git add .            # includes the 3.67 source + .gitignore/.gitattributes
git commit -m "Import VPA 3.67 (intact reference base)"

# 3. Create the working branch
git switch -c port-linux
```

---

## 6. Per-file migration recipe (recurring patterns)

Learned while porting the first unit (`UNIT/STRF.PAS`). These patterns repeat:

1. **Borland segment/overlay directives** → remove. `{$C MOVEABLE PRELOAD
   PERMANENT}` and similar make no sense on Linux (FPC only emits an "Illegal
   compiler directive" warning, but it's better to remove them).
2. **`{$V-}` (var-string checks)** → add right after the unit declaration. BP7 had
   it set globally in `BPC.CFG` (`/$V-`); without it, FPC in TP mode gives
   *"String types have to match exactly in $V+ mode"* when passing e.g. a
   `string[20]` to a `var s:string` parameter. There's no command-line flag for
   `$V`, so it goes as a source directive (part of the standard "prologue" of
   every ported file).
3. **16-bit inline assembly** → rewrite in pure Pascal. Asm using 16-bit registers
   and segments (`les`/`lds`, `ES:`/`DS:`, `AX/BX/SI/DI`, `jcxz`, `repne scasb`…)
   doesn't compile on x86-64. The routine is rewritten in Pascal and **its
   behaviour is validated to match** with a small test harness (compiling isn't
   enough).
4. **Encoding** → preserve the original bytes. Several files have tables/text in
   **single-byte DOS** encoding (e.g. `UChr`/`LChr` in STRF with accents). Don't
   let the editor convert them to UTF-8, or those tables get corrupted. Touch only
   the ASCII parts.

> **Status:** `UNIT/STRF.PAS` ported, compiles clean and functionally validated
> (`ItemPos`/`ItemStr` rewritten from asm). It's the first green leaf unit of the
> tree.

### The `preport.py` tool

Automates the **mechanical** steps (1, 2 and 4) of the recipe: normalizes EOLs
while preserving the original encoding, removes `{$C ...}`, and inserts `{$V-}`.
What requires judgement (asm, interrupts, ports, `uses Graph/Dos/WinAPI`) **isn't
touched**: it's detected and flagged with a line number, returning exit code 2 if
manual work remains (0 if clean). It deliberately over-warns (e.g. it flags
asm/`int` even inside comments) to avoid letting anything real slip through.

```bash
python3 preport.py UNIT/VHLP.PAS              # preview (doesn't modify)
python3 preport.py UNIT/VHLP.PAS --in-place   # applies and leaves a .orig copy
```

Units in `UNIT/` that come out **clean** (compile after preport, no manual work):
the ones in the live build depend on `ptcgraph` (`VHLP`, `VHLPMAKE`→via `vhlp`) or
are input-related (`KEYBOARD`, `MOUSE`, Phase 3). `SYSEXT`/`MEMTEST`/`DPMI*`
belong to the dropped DPMI subsystem.

### Global mechanical pass and roadmap

`preport-all.sh` applies `preport.py` to the whole live build at once (with
`.orig` copies), skipping dropped files (`DPMI*`, `MEMTEST`, `SYSEXT`) and the
`SVGA` layer to be replaced:

```bash
bash preport-all.sh           # preview (doesn't modify)
bash preport-all.sh --apply   # applies in place + report in preport-report.txt
```

After the pass over the 40 files of the live build, the **remaining manual work**
by category (this is the roadmap for Phases 2–4):

| Category | Files | Phase |
|---|---:|---|
| `uses Graph` | 26 | **2** (the bottleneck: porting the graphics layer unlocks most of it) |
| `asm` / `assembler` | 15 / 6 | 2–4 (concentrated in graphics, init, combat) |
| `INT/Intr` | 10 | 3–4 |
| `uses Dos` | 5 | 4–5 |
| `uses WinAPI` | 1 | 3 (`MOUSE`, only under `{$IFDEF DPMI}`, which is OFF) |
| `Mem[]` | 3 | 4 |

> **Conclusion:** 26 of ~40 files depend on `Graph`. The `Graph` → `ptcgraph`
> migration (Phase 2) is the **master key** that unlocks most of the tree.
> Important: applying `preport-all.sh --apply` **doesn't** make those files
> compile (missing deps and manual work remain), but it does get the mechanical
> layer done across the whole project.

| Phase | Status | Notes |
|---|---|---|
| 0 — Environment setup | ✅ Completed | Toolchain verified **end-to-end** on Arch (FPC 3.2.2 compiles and links ptcgraph). The `libXxf86dga` case fully resolved (vendored ptc without DGA, see Phase 7). `git init`/import and branch, done (see §4, Phase 0); license contacted and noted (Stefan Reuther), formal close-out in `LICENSE.md`/`MPL-2.0.txt` only pending publication. |
| 1 — Trimming and scaffolding | ✅ Completed | VPAMM dropped; `vpa.cfg`/`Makefile` for FPC. **Every core unit ported and compiling** (`STRF`, `AUXF` and the rest via this §6's recipe). `GREETS.ASM` dropped (stub in `VPAEXIT`). |
| 2 — Graphics layer (`ptcgraph`) | ✅ Completed | Swap applied; SVGA gone. `SCREEN`, `TCOMBAT`, `MESSAGES`, `VPAINIT` and the rest of the graphics core ported, compile and **draw the real star map**. `VPAINIT`: direct `InitGraph(D8bit, m640x480, '')` (no external BGI drivers). Ship/combat sprites, StarBases and the screensaver working (see "Current status (runtime)", item 8). |
| — *Stubbed* features (restored) | ✅ Resolved | (1) **Hull-functions**: `IsShipFunc3`/`ShipOrHullDoes` **implemented** over the old model (see §1 and "Current status"); only the PCC2-style `Enum*` layer stays under `{$IFDEF VPACC}` (off, decision made). (2) **`KbdFlags`** (Shift/Ctrl/Alt) → **resolved** (current state via X11 `XQueryPointer`). (3) **`TCOMBAT.LoadPic`**: the combat viewer's planar (4-plane) VGA sprite decoder + palette + rotation **ported** to Pascal; `SetPal` implemented. |
| — VPACC/HULLFUNC compat layer | ✅ Unblocked | Added to `VPADATA` (`{$IFNDEF VPACC}` branch): state vars (`BL0`, `bOver`, `mt0/mt1`, `MineN`…), consts (`iBeam`…`iRace`), ~40 `SPC_*`, the `THullFuncQueryResult` type, `IsHullFunc` declaration. `IsHullFunc` (asm) ported to Pascal; **`ShipOrHullDoes`/`IsShipFunc3` implemented** bridging the `SPC_*` to the old model (fleet chunneling and advanced cloaking are now detected). **`VPA4`, `VPA2`, `CONFIG` compile.** |
| — Range and pointer warnings | ✅ Resolved | The byte-range-out-of-bounds constants in the VPACC-off path (`VPA4:1626`, `CONFIG:517/703`) and the 64-bit pointer truncation (`VPA.PAS`, error handler) were fixed (see §4, Phase 6): made explicit / `ord(...)` / `PtrUInt`. Only benign FPC warnings remain, with no impact. |
| 3 — Input (mouse/keyboard) | ✅ Completed | `MOUSE`→`ptcmouse` and `KEYBOARD`→`ptccrt` ported and validated. **`KbdFlags`** (Shift/Ctrl/Alt) resolved via X11 `XQueryPointer` (keyboard and mouse+modifier). **`PollMouse` wired** into the main input loop (via `KeyPressed`). Navigating map and menus with mouse and keyboard **validated by playing** real games. |
| 4 — Low-level cleanup | ✅ Completed | DOS DPMI subsystem removed (`DPMI*`, `MEMTEST`, `SYSEXT` and their binaries/license). `AUXF`/`STRF` 100% Pascal (no asm). Exhaustive sweep of the core: zero interrupts, ports, DOS memory and live asm. The core's 142 `absolute` uses audited: all *variable aliasing* (portable), none of the hardware form. |
| 5 — I/O and data portability | ✅ Completed | `{$PACKRECORDS 1}` (packing identical to DOS), big-endian compile guard, `/` path separator (was `\`), replicated runtime checks (`-Ci- -Cr- -Co- -Ct-`), case-insensitive paths (`ResolveCase`), and `RST_TRN.PAS` ported (.rst/.trn: name (de/en)cryption, reading `PLANETS.EXE`'s registration record). |
| 6 — First native binary | ✅ Completed | Every unit compiles and links into a 64-bit ELF binary; starts under X11. Range/pointer warnings fixed. `PollMouse` wired in. **Tested with real game data** (PHOENIX4, NORTH12…). |
| 7 — Testing and packaging | 🟡 In progress | **Packaging ✅** and **license ✅** done (see detail in §4, Phase 7: the `vpa-linux-3.67.1-x86_64.tar.gz` package tested like a real user would; `LICENSE.md`/`MPL-2.0.txt` published). Only a thorough comparison against the DOS version under DOSBox remains. |

Legend: ⬜ Pending · 🟡 In progress · ✅ Completed

## 7. Native PHost combat viewer (port of PCC2ng's `pvcralgorithm`)

VPA has its own combat viewer (`VPA/TCOMBAT.PAS`: `Combat(var vcr:VCRData; …)`,
with `Battle`, `FireBeam`, `FireTorpedo`, `LaunchFighter`, `MoveFighters`, `Hit`,
`DrawShield`, `Beam`, `Torpedo`, `Fighter`, `Gauge`, `Blast`…) and it already
**replays VCRs natively** (`MESSAGES.PAS` calls `Combat(vcr,Yes,…)`). The problem:
that algorithm is the **classic THost one, with fixed constants** — it doesn't
read PHost's combat configuration —, so for **PHost** games (like the author's,
PHost 4.1h) it's *approximate*, not exact. That's why the original VPA also
offered launching the external `PVCR.EXE` viewer (PHost's), which isn't open
source and only exists for DOS.

### Decision: port the algorithm, not bundle an external binary

Two paths were evaluated (both suggested by Stefan Reuther):

| | **Option A — `playvcr` (PCC2 1.x)** | **Option B — port `pvcralgorithm` (PCC2ng)** |
|---|---|---|
| In the repo | PCC2 1.x + cpluslib (~20 MB C++) | ~1673 new lines of Pascal |
| Runtime | **SDL 1.2** (`sdl12-compat`) + PCC2 resources | **nothing new** (uses `ptcgraph` + `RESOURCE.PLN` sprites) |
| Look | separate SDL program, PCC2 aesthetic | **integrated** into VPA, its window and sprites |
| PHost accuracy | exact | exact if ported well |
| Effort | low (packaging) | high (port the math + validate) |

**Option B** was chosen: it fits the spirit of the port (self-contained, no new
dependencies — right after just having removed `libXxf86dga`), and it takes
advantage of the fact that VPA **already has the visualisation**; it only lacks
the PHost-exact algorithm. PCC2ng cleanly separates the two things:
`game/vcr/classic/pvcralgorithm.cpp` (~1673 lines of pure combat logic) emits
**8 events** to a `Visualizer` interface (`startFighter`, `landFighter`,
`killFighter`, `fireBeam`, `fireTorpedo`, `updateBeam`, `updateLauncher`,
`killObject`) that map almost 1:1 to the drawing routines VPA already has. The
algorithm is ported to Pascal and wired into `TCOMBAT`.

> **Also verified in passing** that Option A *was* viable (PCC2 1.x + `playvcr`
> compile cleanly with g++ 13, a ~2.9 MB binary that only needs SDL 1.2). It's
> dropped for its footprint and for leaving a foreign satellite program, not
> because it's unfeasible.

### License

`pvcralgorithm` comes from **PCC2ng** (`c2ng`), © Stefan Reuther, under the same
*PCC II License Terms* (BSD-style permissive: keep copyright and mark
modifications; **not** GPL). It's compatible with the port's licensing goal. The
ported Pascal units **keep Reuther's copyright header** and a "derived from
PCC2ng" note.

### Phased plan

- **Phase A — Scaffolding and data mapping** (no math yet) — ✅ **COMPLETED**:
  - ✅ New unit `VPA/PVCRALG.PAS` with the skeleton: the `TVcrObject` type (the
    combatant, equivalent to PCC2ng's `game::vcr::Object`) and the `InitBattle` /
    `PlayCycle` / `PlayFastForward` / `DoneBattle` signatures (stubs) + `Get*`
    state queries.
  - ✅ The `TVcrVisualizer` "visualizer" interface: the **8 events** as
    *callbacks* (`startFighter` / `landFighter` / `killFighter` / `fireBeam` /
    `fireTorpedo` / `updateBeam` / `updateLauncher` / `killObject`), which
    `TCOMBAT` will fill in during Phase C.
  - ✅ `MapVCR`: maps VPA's VCR record (`VCRData`, read as-is from `VCRx.DAT`) →
    `TVcrObject`. **Verified field-by-field by offset** against PCC2ng's classic
    layout (`Vcr` = 100 bytes, `VcrObject` = 42), including unpacking ammunition
    like `database.cpp` does. All combat fields are available.
  - ✅ **Extended `PCONFIG.SRC` parser** (`CONFIG.PAS`): captures the **30 PHost
    combat keys** the algorithm needs (`BeamHitOdds`, `BeamHitBonus`,
    `BeamRechargeRate/Bonus`, `TorpHitOdds/Bonus`, `TubeRechargeRate/Bonus`,
    `BayRechargeRate/Bonus`, `BayLaunchInterval`, shield/damage/crew scalings,
    `MaxFightersLaunched`, `StrikesPerFighter`, `FighterMovementSpeed`,
    `FighterBeamExplosive/Kill`, `FighterFiringRange`, `FighterKillOdds`,
    `BeamFiringRange`, `BeamHitFighterRange/Charge`, `BeamHitShipCharge`,
    `TorpFiringRange`, `FireOnAttackFighters`, `StandoffDistance`,
    `PlanetsHaveTubes`). Stored in the `CombatCfg : TCombatCfg` record
    (VPADATA), almost all **per player** (`IArr11`); distances and ranges in
    `LArr11` (32-bit, since they exceed 16 bits — e.g. `BeamHitFighterRange`
    =100000). `InitCombatCfgDefaults` sets **PHost's defaults** (from PCC2ng)
    before reading the file. Implemented with a `ReadCombatKey` dispatcher hooked
    into the parse loop **without touching the positional `KeyNames` table**
    (zero risk to existing config). The `EMod*` keys (experience) were
    implemented in **Phase F** (the `GetEMod` helper, per-level arrays).
- **Phase B — Port the algorithm** (the math), in blocks from least to most
  dependent — ✅ **COMPLETED AND VALIDATED BIT-EXACT**:
  1. `initBattle` + config pre-computation (hit odds, recharge rates, kill/damage).
     ✅ **Pre-computation ported and verified bit-exact** (`InitBattle` in
     `PVCRALG.PAS`, integer model `PVCR_INTEGER`): per-side `TFixedStatus`/
     `TRunningStatus` state structures; `ComputeBeamHitOdds`/
     `ComputeBeamRechargeRate`/`ComputeTorpHitOdds`/`ComputeTubeRechargeRate`/
     `ComputeBayRechargeRate` (PHost formulas), `DivRound` (`ccvcr.pas:RDiv`),
     `EMV` (`getExperienceModifiedValue`, with experience support added in
     Phase F) and the config option cache; weapon specs from VPA's
     `Beams[]`/`Torps[]` (`kill`/`expl` = kill/damage power). Validated against
     a C++ reference with several inputs (including cases that overflow 16-bit
     → `beam_hit_odds`/`torp_hit_odds` are 32-bit, as in PCC2ng). Added
     `ShipMovementSpeed` to the config parser (missing from Phase A).
  2. PHost's RNG (must be **bit-exact**) and beam/launcher/bay recharge.
     ✅ **RNG ported and verified bit-exact** (`Random64k`/`RandomRange`/
     `RandomRange100`/`RandomRange100LT` in `PVCRALG.PAS`): a 32-bit linear
     congruential generator seeded with `seed shl 16`, identical to
     `pvcr.pas`/`VcrPlayerPHost`. Validated by comparing sequences against a
     C++ reference extracted from `pvcralgorithm.cpp` (identical outputs).
     ✅ **Recharge ported** (`BeamRecharge`/`TorpsRecharge`/`FighterRecharge`):
     each tick, whatever isn't maxed (`<1000`) gains `RandomRange(rate)` with
     the pre-computed `*_recharge` values; notifies the visualizer
     (`updateBeam`/`updateLauncher`). The order of RNG calls (set by
     `playCycle`, block 6) is what preserves bit-exactness.
  3. Beams: `fireBeam` + applying shield/hull/crew damage (`hit`).
     ✅ **Damage model ported and verified bit-exact** (`Hit` +
     `ComputeShieldDamageS`/`ComputeHullDamageS`/`ComputeCrewKilledS`, with the
     Regular and Alternative variants from `pvcralgorithm.cpp`, integer model):
     hits the shield, overflows into the hull and kills crew based on the
     scaled values; validated against a C++ reference in both combat modes
     (shield, hull and crew — identical outputs). ✅ **`BeamFire`** (one beam per
     call: fighter or ship, charge spent, `fireBeam`/`killFighter` events),
     `BeamFindNearestFighter` and `GetDistance`. Critical detail replicated: a
     fighter path's `missing` case still consumes RNG even with no fighter
     present. `SetCapabilities` sets the VCR's flags (DeathRay/Beam).
  4. Torpedoes (`fireTorpedo`).
     ✅ **`TorpsFire` ported**: fires one torpedo per call from the first
     charged tube (`status>=1000`), spends ammunition, rolls `RandomRange100`
     and if `rr <= torp_hit_odds` applies `Hit` (model already verified);
     `torp_kill`/`torp_damage` already carry the non-AC ×2 from the
     pre-computation. Emits `updateLauncher`/`fireTorpedo`. Reuses pieces
     already verified bit-exact.
  5. Fighters (launch/move/land/shoot down, inter-fighter combat).
     ✅ **Ported**: `FighterLaunch` (one per call from a loaded bay),
     `FighterMove` (attackers move toward the enemy; returning ones land upon
     reaching their ship), `FighterAttack` (hits with `Hit` when in range;
     retreats if it overshot the enemy), and `FighterIntercept` (inter-fighter
     combat). This last one **verified bit-exact** against a C++ reference
     (same fighters shot down and same final seed in both the matched and
     degenerate cases), validating the position hash (logical `shr` ≡ C's
     signed `>>` for what matters), bin-based pairing, and the critical order
     of RNG calls.
  6. `playCycle` (orchestrates the combat round) + end condition + `doneBattle`
     (final explosions). ✅ **Ported and validated end-to-end**: `PlayCycle`
     runs the round in PHost's exact order (recharge → launch →
     attack/fire → intercept → move) with the `or` short-circuit explicitly
     replicated; `CanStillFight`, the inactivity detector (`CheckCombatActivity`,
     anti-infinite-loop), `MoveObjects`, and `DoneBattle` (de-scale, land
     surviving fighters, set the result and `killObject`), with `BattleResult`
     exposed. **Full battle verified bit-exact** against a C++ replica of the
     integer algorithm in 3 scenarios (regular combat, alternative combat
     `scale=mass+1`, and ship-vs-planet): same number of ticks, same final
     state for both objects, and the **same final seed** in all three. The
     verification uncovered that the scaled fields (`max_scaled`,
     `damage_limit_scaled`) exceed 16 bits in alternative mode and need
     `longint` — they were already correctly declared that way in
     `TFixedStatus`/`TRunningStatus`.
- **Racial combat bonuses** (checked against PHost 4.1h's documentation,
  `formulas.html`/`config.html`/`rules.html`) — applied through three paths, all
  covered:
  - *Per-player config* (Fed beam recharge, scalings, etc.): the algorithm
    indexes each option by the combatant's **owner** (`EMV(CombatCfg.X, owner,
    …)`), just like PCC2ng. ✅
  - *Per-race branch in the algorithm*: only the **Lizard** (race 2), with its
    150% damage before exploding (`PlayerRace(owner)=2`). ✅
  - *Baked into the VCR record by the host*: mass +50kt, +3 bays, shields and
    `FullWeaponry` for the **Federation** (`AllowFedCombatBonus`) — `MapVCR`
    reads them as-is; PCC2ng's VCR loader doesn't re-apply them either. ✅
  - **Privateers (race 5): ×3 on beam `Kill_Power`.** This isn't via
    `CrewKillScaling` but a factor PCC2ng sets when loading the VCR
    (`database.cpp:87`: `setBeamKillRate(PlayerRace[owner]==5 ? 3 : 1)`), used by
    the algorithm in `fireBeam`. Ported with a `beam_kill_rate` field in
    `TFixedStatus`, set in `InitBattle` and used in `BeamFire`; it affects both
    crew **and** shield (`kill` feeds both formulas in `Hit`). **Validated
    bit-exact** with a Privateer combatant (scenario E4: ship R dies from crew
    wipeout instead of damage, and the bonus disappearing changes the outcome
    of the fight). The other four rates (`BeamChargeRate`, `TorpMissRate`,
    `TorpChargeRate`, `CrewDefenseRate`) match `database.cpp` and remain
    constants. ✅
  - *`checkSide`'s silent fixes (`database.cpp`)*: ✅ ported in `MapSide` (if
    `beamType=0` → `numBeams=0`; if `torpType=0` → `numLaunchers=0`/
    `numTorps=0`; a planet with tubes unpacks ammunition). They weren't the
    cause of the discrepancy, but stay faithful to PCC2ng.
- **Phase C — Wire the visualizer into `TCOMBAT`:** ✅ *done.* The 8 events are
  implemented using VPA's own drawing primitives, with VPA's timing/animation and
  a "no animation" mode.
  - **Design decision (important):** only the **pure drawing primitives** are
    used (`Beam`, `Torpedo`, `Fighter`, `Blast`, `Gauge`, `DrawShield`), **not**
    the high-level `Hit`/`FireBeam`/`FireTorpedo`/`Battle` routines, because
    those **carry THost's math inside them** (e.g. `Hit` recomputes
    shield/damage/crew with the classic formula). The PHost viewer must
    **render PVCRALG's real state**, not recompute anything.
  - **C1 ✅ (done):** PVCRALG exposes read-only accessors so the viewer can query
    live geometry and state: `VcrObjectX`, `VcrFighterX`, `VcrFighterStatus`,
    `VcrActiveFighters`, `VcrBeamStatus`, `VcrLauncherStatus`,
    `VcrCurShield/Damage/Crew` (live de-scaling), `VcrObjInfo`, `VcrDistance`,
    `VcrTime`. The 8 callbacks were already wired into the firing functions
    since Phase B. They're pure reads: they don't touch the math (bit-exactness
    intact).
  - **C2 ✅ (done):** derived and verified coordinate mapping. It's **linear, 100
    metres per pixel**: `screen_X = 320 + objectX/100`. The algorithm uses
    `m_objectX` in `±29000` m (3000 m standoff); the screen uses `SX[Left]=30 …
    SX[Right]=610` (centre 320, 30 px standoff). The ratio matches (58000/3000 =
    580/30), so the mapping is exact for ship-vs-ship. Fighters use the same
    mapping (`fighterX/100`).
  - **C3 ✅ (done):** the 8 callbacks implemented in `TCOMBAT.PAS`
    (`pvStartFighter`, `pvLandFighter`, `pvKillFighter`, `pvFireBeam`,
    `pvFireTorpedo`, `pvKillObject`; `updateBeam`/`updateLauncher` stay `nil` —
    deferred charge indicators). They read the real state via accessors and
    draw with the pure primitives; the gauges animate the "old→new" sweep by
    reusing the `shld/dam/crew/tf` globals as the "last shown value".
  - **C4 ✅ (done):** the `CombatPHost` driver (same setup as `Combat` →
    `MapVCR` → `SetCapabilities`/`SetPhost3` → `InitBattle` → a
    `while PlayCycle` loop with `pvUpdateShips`/`pvUpdateFighters` + `Delay` +
    keys → `DoneBattle` → dumps results back to the VCR). **Compiles and
    links** (clean build).
  - **Phase C caveats (✅ later polished):** the ship sprite's movement against a
    planet — **fixed**: `pvUpdateShips` clamps the drawing position so the ship
    doesn't get inside the disc (anti-overlap clamp, without touching the real
    displayed distance); `pvKillObject` — **fixed**: the driver now draws the
    full explosion with the `ExplPic` sprite (on top of everything, after the
    refreshes, removing the shield first), not a simple `Blast`; fighter
    trails — **fixed** in Phase E (the `pvFH` array, erasing each fighter with
    the same shape it was drawn with); **fighter Y-staggering — verified as no
    real problem**: `pvFY` sets the height only by `track mod 10` (not by its X
    position), so within a single wave launched in sequence the natural result
    is a staggered diagonal (each fighter having flown a little further than
    the next), not an overlap; checked with real screenshots showing up to 74
    fighters per side with no two icons landing at the same height.
    `SetPhost3` is set to `False` at this stage (PHost 3-vs-4 detection is
    Phase D's job, which corrects it to `True`). **Visually verified** against
    `PVCR.EXE` in Phase E.
- **Phase D — Integration into VPA:** ✅ *done.* The native PHost viewer is wired
  into `MESSAGES.PAS`:
  - **`ViewVCR`** (watch a battle): for **PHost** (`pvcr`) calls
    `CombatPHost(vcr,Yes,…)` (the ported, animated algorithm) instead of
    building a temp file and `Exec(PVCR.EXE)`; for **THost** it keeps the
    classic `Combat`. All of `PVCR.EXE`'s machinery (temp file, rename, `Exec`,
    `SwapVectors`) **removed**.
  - **`GetVCRMessage`** (message summary): for PHost it no longer bails out
    before computing anything — it runs `CombatPHost(vcr,No,…)` without
    animation to get the outcome and show the `/Destroyed/`/`/Captured/`
    labels, same as THost. (For this, `CombatPHost` dumps the result into
    `dd[lr].pic` with `ExplPic`/`SurrPic`.)
  - The ***View* key** enabled for PHost always (the `pvcrexe` requirement was
    removed), and the obsolete *"Copy PVCR.EXE…"* notice removed.
  - **CRITICAL (race vs owner):** the PHost path passes the **raw** `vcr`
    (without the `dd[lr].race := Race[…]` conversion THost does before
    `Combat`). `MapVCR` sets `owner := race` (player slot) and **PVCRALG
    applies `Race[]` internally** via `PlayerRace(owner)`; pre-converting would
    cause a double conversion (`Race[Race[slot]]`).
  - **`SetPhost3(True)`** (not `False`): the name is misleading —
    `pvcralgorithm.hpp` documents `false=PHost 2.x, true=PHost 3.x/4.x`. PHost 3
    and 4 use the same branch (`true`); only the obsolete PHost 2.x would use
    `false`. Correct for Pablo's 4.1h game.
  - Clean build; starts under Xvfb. **Visual verification completed** (see
    Phase E).
  - **Combat simulator (F5) wired in** (`VCS.PAS`): VPA's simulator builds a
    `VCRData` in memory and, until now, **always** called the classic `Combat`
    (THost math), even for PHost games. It now routes the same way as the
    viewer: for **PHost** (`if PHOST then`) it uses `CombatPHost` (PHost's math,
    ported from PCC2ng, already validated bit-exact); for **THost**, the
    classic `Combat`. *Anti-LeftWin* (a THost heuristic that adds 360 mass to
    the right side to offset the left side's win bias) is **skipped for PHost**
    —PHost combat is mass-based and that `+360` would skew it— (it was in fact
    already disabled for PHost via `VCSet bit 4`; the explicit `not PHOST`
    documents it). The simulator's ships are level 0 (there's no interface to
    set experience), so `VcrFileCaps:=0` is set → **base** PHost combat, no
    rank line. Since `CombatPHost` dumps the final result to
    `dd[lr]`/`shld[lr]` just like `Combat`, the simulator's summary
    (`WriteResult`) correctly shows the PHost outcome.
- **Phase E — Validation (critical):** ✅ *done.* Validated **bit-exact against
  `PVCR.EXE`** (DOSBox) on real combats from the PHOENIX4 game (PHost 4.1h),
  comparing a video frame by frame: winner, final damage, survivors, ammunition,
  shield/crew and fighter count all match (e.g. combat 2: Crystalline ship vs.
  Empire planet → the ship wins with 65 torpedoes, the planet dies with 18
  fighters in reserve; ship shield 9.8, crew 1035).
  - **Root cause found and fixed:** carrier/planet combats came out *reversed*
    compared to `PVCR.EXE` **not** because of the math, but because VPA wasn't
    opening `pconfig.src` (lowercase) on Linux → it used the default config with
    `AllowAlternativeCombat=No`. Fixed with `ResolveCase` (see Phase 5). With the
    real config loaded, the result matches.
  - **Reproducible test bench** (`/tmp/t2/*.pas`): harnesses running the real
    `PVCRALG` over `VCR7.DAT`, loading `beamspec.dat`/`torpspec.dat`, with a
    4-way table (config×altcombat) isolating the decisive variable, and a
    step-by-step walk through `PlayCycle` printing fighter reserve/in-flight
    counts at each distance for cross-checking against the video frames.
  - **Fighters in reserve:** the counter shows **only** the fighters in the bay
    (`numFighters`), not the ones in flight, just like `PVCR.EXE` (verified: 21
    in reserve at 35600 m, not 51).
  - **Fighter trails:** erasing fixed (each fighter is erased with the same
    shape `h` it was drawn with, via `pvFH`); no more trail left behind when
    moving.
- **Phase F — Experience levels (PHost 4.x)** — ✅ **COMPLETED and validated
  bit-exact.** In PHost 4 every unit (ship or planet) has an **experience
  level** (0..`NumExperienceLevels`, with `NumExperienceLevels` between 0 and
  10). The level modifies combat: config options are adjusted with the
  **`EMod*` modifiers** per PCC2ng's formula (`getExperienceModifiedValue`):
  `effective_value = clamp(base[player] + EMod[level], min, max)`, applied to
  ~20 parameters (`BeamHitOdds`/`Bonus`, beam/tube/bay recharges,
  `ShieldDamage`/`ShieldKillScaling`, `HullDamageScaling`, `CrewKillScaling`,
  `MaxFightersLaunched`, `StrikesPerFighter`, `Fighter*`,
  `BeamHitFighterCharge`).
  - **Parser** (`CONFIG.PAS`): a `GetEMod` helper that captures the 20 `EMod*`
    keys **per level** (accepts both `4,4,5,8`-style lists and a single value
    `0`, propagated to every level); defaults to 0. `NumExperienceLevels` was
    already being read.
  - **Data** (`VPADATA.PAS`): the `EArr = array[1..10] of int` type and `EMod*`
    fields in `TCombatCfg`.
  - **Algorithm** (`PVCRALG.PAS`): each unit's level was already being read from
    the VCR record (`experienceLevel` at offset 33 of the object, after
    `numBeams`). `EMV` now adds the unit's `EMod[level]`; PCC2ng's
    **consistency reset** was added: if the file doesn't declare
    `ExperienceCapability` or the level exceeds `NumExperienceLevels`, the unit
    is reset to level 0.
  - **File capabilities (subtle bug fixed)** (`MESSAGES.PAS` + `TCOMBAT.PAS`):
    following `classicvcr.cc`, the capabilities (DeathRay/Experience/Beam) are
    determined **only once, from the first record** of the VCR file —
    `(firstFlags & 0x8000) ? firstFlags & ~0x8000 : 0`— and apply to **every**
    combat. In a real PHost file only the 1st record carries the
    `ValidCapabilities` bit (0x8000); the rest carry flags = 0. Before, the
    viewer used the **per-record** flags, which **disabled experience from the
    2nd combat onward**. Now `GetVCR` computes `VcrFileCaps` from record #1 and
    the viewer uses that.
  - **Validation:** bit-exact against PCC2's **`pvcr-exp`** test (6/6 combats,
    with level-2 and level-3 units), exercising the full stack: the real
    `pconfig.src` parser → `EMod` → combat with experience. End time, winner and
    final shield/damage/crew/ammunition all match. Also verified that the
    parser correctly reads a real game's `pconfig.src` (NORTH12,
    `NumExperienceLevels=4`) and **without regression** in combat without
    experience (PHOENIX4).
  - **Rank name in the viewer — ✅ done.** The viewer shows `Rank : ` plus the
    rank name (`ExperienceLevelName(ex)`, parsed from `ExperienceLevelNames` in
    `pconfig.src`), only if the VCR file declares `ExperienceCapability`, with
    the same consistency reset as the rest of Phase F (out-of-range level → 0).
  - *(Pending/optional: death rays and the multi-ship **FLAK** combat
    (`game/vcr/flak/` from PCC2ng). No date set; they don't block the rest of
    the viewer.)*

> **Status:** ✅ **functional and validated bit-exact against `PVCR.EXE`.** The
> native PHost viewer fully replaces `PVCR.EXE`: same unfolding, same
> frame-by-frame counters, and the same outcome. Only cosmetic touches remain
> (see *Known limitations*). Stefan Reuther remains available for questions on
> the algorithm's finer points.

### Current status (runtime)

The native binary **works and is playable**. Resolved, in order, the issues that
made the program look "frozen":

1. **Keyboard focus** — under window managers like Cinnamon, `ptc` wasn't
   requesting keyboard focus on open. New unit **`xfocus`**: finds the window by
   title and does `XSetInputFocus` + `_NET_ACTIVE_WINDOW`. Keyboard 100%
   operational.
2. **Help file** — the original `VPA.HLP` was a DOS binary (Borland record
   packing ≠ FPC). Regenerated from `VHLP/VPA.HHH` with **`make hlp`** (uses
   `xvfb-run` because the help compiler links the graphics layer). The resulting
   `VPA.HLP` needs to be copied to the game folder.
3. **Mouse not enabled** — `MousePresent` stayed `False` (DOS's INT33 detection
   was removed). Defaults to `True` on Linux (`/K` still disables it).
4. **Runaway scroll** — the scroll loop depended on DOS's mouse interrupt. Now
   it polls the mouse each loop and doesn't scroll if the pointer is outside the
   window (`xfocus.PointerInsideWindow` via `XQueryPointer`).
5. **CPU at 100% / fan spin-up** — the main loop was busy-waiting (nothing to
   yield to under DOS). Added `Keyboard.CpuNap` (a ~5 ms sleep) in the idle loop
   and in continuous scroll. Idle usage ~0%.
6. **System cursor** — left visible and behaving normally inside/outside the
   window (the earlier hidden-cursor approach made it disappear outside).
7. **Resizable window and fullscreen** — `VPA_SCALE` enlarges the window (the
   surface stays 640×480 and `ptc` scales it) and `VPA_SCALE=fullscreen` fills
   the whole screen above the desktop panel, **without** changing the video
   mode. The mouse is rescaled both ways to keep pixel-perfect precision (see
   §1 and §4).
8. **Ship/combat sprites** — ported the planar (4-plane) VGA sprite decoder +
   palette + truncation + rotation + mirroring, assembling the image in
   `ptcgraph` format. Ships now show correctly in the **combat simulator** (both
   sides, with colour and animation), the **StarBases** (build screen), and the
   screensaver. The game's palette is saved/restored around combat so it
   doesn't alter the map's colours.
9. **Exit with/without saving** — **Alt-X** and the window's **[X]** button exit
   **saving**; **Ctrl-Alt-X** exits **without saving** after asking for
   confirmation (Y/N). The intent is fixed deterministically on the keypress
   itself (modifier state isn't read at close time).
10. **Mouse jumpy on load** — on open, the cursor is centred and `ptcmouse`'s
   internal position is synced with the warp, so the map no longer auto-scrolls
   on its own until the user moves the mouse.
11. **Crash buying torpedoes/fighters** — entering "Buy torps/fighters" at a
   StarBase used to abort with `RunError(250)` ("NOT ENOUGH MEMORY"). Cause: the
   menu reserves a buffer to save the screen underneath (`MenuSize`→
   `ImageSize`), and in 256 colours (`D8bit`) that buffer weighs ~2 bytes/pixel
   — much more than DOS BGI's 16-colour planar format —, so it exceeded the
   `ReservedMemory=30000` limit checked by `UnLockReservedMemory`. Measured:
   that menu's region comes to 30438 bytes. `ReservedMemory` raised to
   **65536** (screen buffers are stored in a `word`, ≤65535, so 64 KB covers
   them all; reserving it is free on Linux).
12. **Shift/Ctrl/Alt modifiers** — `KbdFlags` now queries the **current** state
   of modifiers from X11 (`XQueryPointer`, like DOS's BIOS `0040:0017`), so both
   keyboard shortcuts (Shift/Ctrl+arrow…) and **mouse+modifier** (e.g. map zoom
   with Shift/Ctrl and the middle button) work. Also, the vendored `ptccrt` now
   emits **Alt+arrow** (`$9B00`/`$9D00`/`$A000`/`$9800`) in `kmTP7` mode too —
   the one VPA uses— not just in `kmGO32/kmFPWINCRT`; previously they were
   swallowed and map panning and ±100 adjustments didn't arrive. All validated
   by event injection under Xvfb.
13. **VPA's own crosshair (cursor)** — VPA shows its original **white
   crosshair** as the cursor, instead of the system pointer. Implemented in the
   vendored `ptc` (`x11/x11windowdisplayi.inc`): its "visible" cursor becomes a
   white cross (same shape as the original `CrossPointer`/`MouseMotionHandler`,
   **symmetric**), set **per-window** on ptc's own window
   (`XChangeWindowAttributes`/`CWCursor`) — the same mechanism ptc already used
   for the invisible cursor —, so it's **only visible inside VPA** and the
   desktop gets its pointer back on exit. It's done in ptc (and not in
   `xfocus` with `XDefineCursor`) because ptc used to reset the cursor to
   `None` on every `ShowMouse`, overriding any external `XDefineCursor`. The
   crosshair is **auto-scaled** to the window's scale (`AWidth/640`,
   nearest-neighbour, capped at 4×) so it looks the right size at 2×/fullscreen
   (X cursors render at native pixels, `ptc` doesn't scale them with the
   content). Also, the cursor warp (`MapSurfaceToWindow`) is centred within the
   scaled block (not the corner) so the cross lands centred on
   planets/objects. Note: VPA's real crosshair is **symmetric**; the slight
   asymmetry seen in DOSBox isn't in the cursor itself but is introduced by
   DOSBox's scaler (often stretching to 16:9), so it isn't reproduced —
   faithfulness to the original cursor is prioritised.

### Known limitations

| Topic | Status | Detail |
|---|---|---|
| Combat decimals | 🔒 By design (accepted) | The viewer shows shield/damage/crew with one decimal (like `PVCR.EXE`) and the **integer part matches** (e.g. shield 9.8). The first decimal can differ by ~±0.5: `PVCR.EXE` accumulates the sub-unit fraction differently from PCC2ng (they agree at integer crossings — hence the bit-exactness of the **result** — but not in the fraction). Matching the exact decimal would require abandoning the algorithm faithful to PCC2ng, so it's **left this way on purpose**: staying 100% faithful to the ported code is prioritised, and the algorithm's correct value is shown. |

### Bitmap font sources (`.FNT`)

VPA supports `Font=file.fnt` in the `[System]` section of `vpa.ini` to load an
**8×16** bitmap font (256 characters × 16 bytes = 4096 bytes) into its internal
`StandardFont` buffer (the one `WriteXY` uses). The official distribution
includes `LATIN1.FNT` (Latin-1, ideal for Linux), `SANSERIF.FNT`, `THIN.FNT` and
several DOS *code pages*. **Note:** this does **not** affect the map's planet
names, which use the vector font (`OutTextXY`).
