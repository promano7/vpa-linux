# License

**VPA-Linux** is a native GNU/Linux port of **VGA Planets Assistant (VPA) 3.67**.
It is a *derivative work that combines several components released under different
(but compatible) open-source licenses*. This file explains which license applies to
which part, and lists every copyright holder whose work is included. **All original
copyright notices are retained.**

> **Short version**
> - The original **VPA** code — and any changes made to it — stays under the
>   **Mozilla Public License (MPL)**.
> - Code **ported from PCC2 / PCC2ng** (the native PHost combat viewer) stays under
>   the permissive **PCC II License Terms** (BSD-style).
> - The **vendored Free Pascal** files (PTCPas and `ptcgraph`/`ptccrt`), including
>   the SDL3 console this port adds to PTCPas, stay under the **GNU LGPL with the
>   static-linking exception**.
> - The vendored **SDL3-for-Pascal** bindings are under the **zlib license**.
> - The binary packages also carry an unmodified build of the **SDL 3** library
>   (`plugins/libSDL3.so.0`), under the **zlib license** — see `LICENSE.SDL3.txt`
>   in the package. SDL is **not** part of this source tree.
> - The files **written specifically for this Linux port** are **BSD 3-Clause**,
>   © 2026 Pablo Romano Gómez.

---

## 1. Components and their licenses

| Component | Where | License | Copyright |
|---|---|---|---|
| **VGA Planets Assistant** core, and all port modifications to it | most of `VPA/`, `UNIT/`, `VHLP/` | **Mozilla Public License** (the SourceForge project lists **MPL 1.1**) | Alex V. Ivlev (© 1993–1996); the VPA maintainers / VPA-TEAM (© 1998, © 2003 and later) |
| **PCC** command code | `CC/` | **PCC II License Terms** (permissive, BSD-style) | © 2001–2024 Stefan Reuther & contributors |
| **PHost combat viewer**, ported from PCC2ng | `VPA/PVCRALG.PAS` and the parts derived from it wired into `VPA/TCOMBAT.PAS` and `VPA/MESSAGES.PAS` | **PCC II License Terms** (permissive, BSD-style) | © Stefan Reuther & contributors |
| **Vendored Free Pascal** run-time files | `VENDOR/` except `VENDOR/sdl3/` (`ptcgraph.pp`, `ptccrt.pp`, the `.inc` files they include, `ptc/…`) | **GNU LGPL with the static-linking exception** (the modified LGPL under which FPC ships) | © 2010–2011 Nikolay Nikolov; © 2007 Daniel Mantione; and the Free Pascal development team |
| **SDL3 console for PTCPas**, written for this port | `VENDOR/ptc/sdl/` (`sdlconsoled.inc`, `sdlconsolei.inc`) | **GNU LGPL with the static-linking exception**, the same terms as the PTCPas library it is compiled into | © 2026 Pablo Romano Gómez |
| **SDL3-for-Pascal** bindings, v0.6 (one file modified, and marked) | `VENDOR/sdl3/` | **zlib license** (`VENDOR/sdl3/LICENSE.md`) | © 2024 Pascal Game Development Team |
| **SDL 3.4.16** shared library — **binary packages only**, not in this repository | `plugins/libSDL3.so.0` in the package assembled by `make data`, built from the unmodified official tarball | **zlib license** (`LICENSE.SDL3.txt` in the package) | © 1997–2026 Sam Lantinga and the SDL contributors |
| **New port code**, build tooling and documentation | `GRAPH/` (the VPAGraph core, ABI and plugin loader), `BACKENDS/` (the X11 and Wayland plugins), `TESTS/`, `tools/`, `docs/`, `WAYLAND.md`, `UNIT/xfocus.pas`, `Makefile`, `vpa.cfg`, `plugins.cfg`, `preport.py`, `preport-all.sh`, `swapgraph.py`, `setup-env.sh`, `README.md`, `README.es.md`, `README.en.md`, `BUILD.es.md`, `BUILD.en.md`, `HOWTO.es.md`, `HOWTO.en.md`, this `LICENSE.md`, … | **BSD 3-Clause** | © 2026 Pablo Romano Gómez |
| **Map label font** (BGI stroked font "LITT") | `LITT_VPA.CHR` | **© Borland International** — a Borland Graphics Interface (BGI) runtime font, not covered by the licenses above (see note below) | © 1987–1988 Borland International |

### Important notes

- **MPL is a file-level (weak) copyleft.** Because most of VPA's source files were
  published under the MPL, the changes this port makes *to those files* are also
  covered by the MPL, and their source remains available under the MPL. The
  **BSD 3-Clause** grant in §3 covers the files that are *wholly new* in this port
  (not derived from the MPL-licensed originals).
- **The PDK was used only as reference.** During the port, the PHost Development Kit
  (PDK, GPL v2-or-later) was consulted to confirm numbering and semantics, but **no
  PDK source code was translated or included** in this project. The PDK's GPL therefore
  does **not** apply to this work. Its authors are credited below regardless.
- **Data formats are facts.** The VGA Planets on-disk formats (`.DAT`, `.RST`, `.TRN`,
  `VPAx.DB`, …) are factual and not subject to copyright.
- **Removed component.** The DOS-only DPMI subsystem (D4TP, © 2000–2002 Stefan Reuther)
  that shipped with the original was **removed** from this port, together with its
  separate license file.
- **Modified vendored files carry notices.** Each modified file under `VENDOR/`
  (`ptcgraph.pp`, `ptccrt.pp`, `fontdata.inc`, `ptc/ptc.pp`, `ptc/ptcwrapper.pp`,
  the `ptc/core/` console includes, `ptc/x11/x11consoled.inc`,
  `ptc/x11/x11extensions.inc`, `ptc/x11/x11consolei.inc`,
  `ptc/x11/x11windowdisplayi.inc` and its `.d.inc`, and `sdl3/SDL3.pas`) keeps a
  notice stating what was changed, as the LGPL and the zlib license require.
- **Where the LGPL code ends up.** The executable `VPA` no longer contains any of
  the vendored Free Pascal graphics code: it is linked into the two plugins,
  `plugins/libvpagraph-x11.so` and `plugins/libvpagraph-wayland.so`, under the
  static-linking exception, and the complete source of that code, modifications
  included, is in `VENDOR/`. The plugins talk to the executable only through the
  VPAGraph ABI (`GRAPH/vpagraph_abi.inc`), which is new port code.
- **SDL 3 is used as a separate shared library.** The Wayland plugin loads
  `libSDL3.so.0` dynamically: the copy shipped next to it in the binary packages,
  or the system's if that copy is deleted. The shipped copy is built by `make sdl3`
  from the official, unmodified SDL 3.4.16 source tarball (its SHA-256 is pinned in
  the `Makefile`), with only the subsystems VPA uses enabled. The zlib license asks
  for no attribution in binary form; its text is shipped anyway as
  `LICENSE.SDL3.txt`. The SDL source tree also contains a few third-party parts
  under other permissive licenses (MIT, BSD, Apache-2.0); see the SDL tarball for
  their notices.
- **Cyrillic glyphs in `VENDOR/fontdata.inc`.** Glyphs #128–#255 of the 8×8 bitmap
  font were replaced with the CP866 Cyrillic set from `Cyr_a8x8.psf`, one of the
  Linux `kbd` / `console-setup` console fonts, which are **public domain**; the file
  header records it.
- **`LITT_VPA.CHR` is a Borland BGI font.** This map-label font is the stock Borland
  Graphics Interface stroked font *"LITT"* (Small Font); its own header reads
  *"Copyright (c) 1987,1988 Borland International."* It was embedded in the original
  DOS VPA (as the linked `LITT_VPA.OBJ`) and is carried over here as the equivalent
  `.CHR`. It is **not** original port work and is **not** covered by the MPL, BSD, PCC
  or LGPL terms above — its copyright is Borland's. VPA runs without it (it falls back
  to a built-in font), so it is **optional**. If a fully unencumbered redistribution is
  desired, this file can be replaced with a free stroked font or omitted.

---

## 2. Copyright holders

- **Alex V. Ivlev** — the original VGA Planets Assistant (© 1993–1996).
- **The VPA team / VPA-TEAM** — subsequent VPA maintenance (© 1998, © 2003, …).
- **Stefan Reuther & contributors** — PCC, PCC2 and PCC2ng (`CC/` and the combat
  viewer) (© 2001–2024).
- **Nikolay Nikolov, Daniel Mantione, and the Free Pascal development team** — the
  vendored Free Pascal run-time files in `VENDOR/`; PTCPas is a port of the OpenPTC
  C++ library by **Glenn Fiedler**.
- **The Pascal Game Development Team** — the SDL3-for-Pascal bindings in
  `VENDOR/sdl3/` (© 2024).
- **Sam Lantinga and the SDL contributors** — the SDL 3 library shipped in the
  binary packages (© 1997–2026).
- **Borland International** — the BGI stroked font `LITT_VPA.CHR` (© 1987–1988).
- **Andrew Sterian, Thomas Voigt, Steffen Pietsch, Maurits van Rees, Stefan Reuther**
  — the PHost Development Kit (PDK), consulted as reference only.
- **Pablo Romano Gómez** — the GNU/Linux native port (© 2026).

---

## 3. BSD 3-Clause License — for the new port code by Pablo Romano Gómez

Copyright (c) 2026 Pablo Romano Gómez

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---

## 4. Full texts of the other licenses

The complete text of each of the other licenses applies to its component. Where a
component already carries its terms in its own file headers (as the `VENDOR/` files
do), those govern.

- **Mozilla Public License (MPL)** — <https://www.mozilla.org/en-US/MPL/>. The
  original VPA project on SourceForge is tagged **MPL 1.1**; a copy of the MPL should
  accompany the VPA-derived files in any redistribution (MPL 2.0 is the current
  version).
- **GNU LGPL + Free Pascal static-linking exception** — see the headers of the files
  in `VENDOR/` and <https://wiki.freepascal.org/faq#Licensing>.
- **zlib license** — for the SDL3-for-Pascal bindings, the full text is
  `VENDOR/sdl3/LICENSE.md`; for the SDL 3 library, it is `LICENSE.txt` in the SDL
  tarball, shipped in the binary packages as `LICENSE.SDL3.txt`
  (<https://www.libsdl.org/license.php>). In essence: do not misrepresent the
  origin, mark altered source versions as such, and keep the notice in source
  distributions.
- **PCC II License Terms** — the permissive terms under which PCC2 / PCC2ng are
  published; see the header of `VPA/PVCRALG.PAS` and the PCC2 source. In essence:
  retain the copyright notice, mark your modifications, no warranty, and no
  endorsement.
- **BSD 3-Clause** — reproduced in full in §3 above.

---

## 5. Attribution

This program is based on the original **VGA Planets Assistant** by Alex V. Ivlev,
published on SourceForge under the Mozilla Public License:

> _based on original work published at_ **<https://sourceforge.net/projects/vpa/>** _under the MPL license._

The native PHost combat viewer is derived from **PCC2ng** by **Stefan Reuther**
(the PCC2 project), used under the PCC II License Terms.

The native Wayland backend draws with **SDL 3** (<https://www.libsdl.org/>) through
the **SDL3-for-Pascal** bindings (<https://github.com/PascalGameDevelopment/SDL3-for-Pascal>),
both under the zlib license.

*VGA Planets* is a trademark of its respective owner. This is an unofficial,
fan-made helper program; it ships with no VGA Planets game data.

---

## 6. No warranty / not legal advice

This software is provided **"as is"**, without warranty of any kind; see each
component's license for the exact terms. This summary is provided in good faith for
convenience and is **not legal advice**; where this file and an included license text
differ, the license text governs.
