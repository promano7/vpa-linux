# ============================================================================
# Makefile — Port of VGA Planets Assistant (VPA) 3.67 to GNU/Linux (Free Pascal)
# Replaces Borland Make's MAKEFILE. See BUILD.en.md for requirements and usage.
# ============================================================================

FPC  ?= fpc
CFG   = vpa.cfg
MAIN  = VPA/VPA.PAS
BIN   = build/VPA

# Vendored ptc backend, recompiled WITHOUT the X11 DGA extension (see VENDOR/ptc),
# so that nothing depends on the obsolete libXxf86dga (dropped by Arch).
# Since Phase 6 of WAYLAND.md the executable does NOT link ptc any more: the X11
# plugin has its own PIC build (plugin-units). build/ptcunits is only used by the
# 'direct' reference variants of the tests (direct-units).
PTCSRC   = VENDOR/ptc
PTCUNITS = build/ptcunits

# Distributable package assembled by 'make data': the compiled binary, the
# compiled help file, the EXAMPLES/ folder and the runtime data + documents.
PKGDIR    = build/vpa-linux_package
PKGFILES  = DISTTABL.DAT HOWTO.en.md HOWTO.es.md LICENSE.md LITT_VPA.CHR \
            MPL-2.0.txt VPA.MSG

# VPAGraph ABI test bench (WAYLAND.md, Phases 2 and 3): the five test plugins of
# TESTS/abi/ and the dynamic loader harness, all built into build/abi/. Plugins
# are plain FPC libraries (objfpc, PIC), so they do NOT use @vpa.cfg; the two
# *_tp.pas units are compiled exactly as VPA is (-Mtp, checks off) to prove that
# the -Mtp side can consume the ABI and the loader.
ABIDIR    = build/abi
ABIPLUGS  = stub_backend bad_nosymbol bad_abiversion bad_structsize bad_nullprocs \
            bad_unresolved
FPCPLUG   = $(FPC) -MOBJFPC -Cg -FiGRAPH -FU$(ABIDIR)
FPCTP     = $(FPC) -Mtp -Ci- -Cr- -Co- -Ct- -FiGRAPH -FuGRAPH -FU$(ABIDIR)

# Graphics backend plugins (WAYLAND.md, Phase 5): every subdirectory of
# BACKENDS/ is one .so, built with @plugins.cfg (objfpc, PIC, checks ON) against
# a separate PIC build of the vendored ptc/ptcwrapper/ptcgraph in
# build/plugins/units/ (same options as the executable's copy, so the plugin
# draws exactly what the executable draws). build/ptcunits/*.ppu are NOT PIC
# and cannot be linked into a shared object.
PLUGDIR   = build/plugins
PLUGUNITS = $(PLUGDIR)/units
PLUGCFG   = plugins.cfg
X11PLUGIN = $(PLUGDIR)/libvpagraph-x11.so
# Wayland plugin (WAYLAND.md, Phase 8, route B): the SAME ABI adapter as the X11
# plugin (BACKENDS/X11, built with -dVPAG_WAYLAND) on a second PIC build of ptc
# whose console is VENDOR/ptc/sdl (-dPTC_SDL3). Needs libSDL3 >= 3.4.4 to link;
# if it is not in a standard path: make wayland-plugin SDL3_LIBDIR=/usr/local/lib
WLPLUGIN  = $(PLUGDIR)/libvpagraph-wayland.so
WLUNITS   = $(PLUGDIR)/units-sdl3
WLOBJ     = $(PLUGDIR)/wayland
SDL3SRC   = VENDOR/sdl3
SDL3LIB   = $(if $(SDL3_LIBDIR),-Fl$(SDL3_LIBDIR))
WLPTCFLAGS = -O2 -dPTC_SDL3 -Fi$(PTCSRC) -Fi$(PTCSRC)/core -Fi$(PTCSRC)/sdl -Fu$(PTCSRC) -Fu$(SDL3SRC) -Fi$(SDL3SRC)
WLTESTS   = build/wayland
WESTON    = TESTS/wayland/con-weston.sh
X11TESTS  = build/x11
# ptcgraph/ptccrt/ptcmouse built the way the executable linked them before
# Phase 6 (-Mtp command line, checks off, non-PIC, against build/ptcunits). The
# executable no longer uses them; they are the REFERENCE the 'direct' variants
# of scene-test, graphapi-test and coreinput-test compare the plugin against.
DIRECTUNITS = build/directunits
# Pruebas del nucleo VPAGraph (Fase 6). Se compilan en -Mtp con las opciones
# de vpa.cfg, porque lo que prueban es que el nucleo se consume desde ahi.
CORETESTS = build/vpagraph
FPCCORE   = $(FPC) -Mtp -Ci- -Cr- -Co- -Ct- -vwn

.PHONY: all build clean run help hlp data ptc debug heaptrc abi-plugins loader-test detect-test \
        plugin-units x11-plugin wayland-units wayland-plugin wayland-test plugins threads-test nodisplay-test window-test input-test scene-test deps-test \
        graphapi-test initgraph-test coreinput-test direct-units

# 'data' runs 'build' and 'hlp', and both drive fpc over the same build/
# directory: never run them concurrently, even with 'make -jN'.
.NOTPARALLEL:

all: build

## build : build the executable into build/VPA and the graphics backend plugins
##         into build/plugins/. The executable links no graphics library: it
##         loads <its own directory>/plugins/libvpagraph-<backend>.so at run
##         time (WAYLAND.md), so the two always travel together.
build: plugins
	@mkdir -p build
	$(FPC) @$(CFG) $(MAIN)
	@cp -f LITT_VPA.CHR build/ 2>/dev/null || true
	@echo ""
	@echo ">> Done: $(BIN)"

## ptc  : rebuild the ptc backend WITHOUT the DGA extension (avoids depending on
##        libXxf86dga), plus the vendored ptcwrapper/ptceventqueue (WAYLAND.md,
##        T5.3b: ptc's console interface gained GetX11WindowID, so the system
##        ptcwrapper.ppu no longer matches). Rebuilt only when the vendored
##        source changes.
##        Note: ptc is plain FPC code (not -Mtp), so it does NOT use @vpa.cfg.
PTCFLAGS = -O2 -Fi$(PTCSRC) -Fi$(PTCSRC)/x11 -Fi$(PTCSRC)/core -Fu$(PTCSRC)
ptc: $(PTCUNITS)/ptcwrapper.ppu
$(PTCUNITS)/ptcwrapper.ppu: $(PTCSRC)/ptc.pp $(wildcard $(PTCSRC)/*.pp) $(wildcard $(PTCSRC)/x11/*.inc) $(wildcard $(PTCSRC)/x11/*.pp) $(wildcard $(PTCSRC)/core/*.inc) $(wildcard $(PTCSRC)/core/*.pp)
	@mkdir -p $(PTCUNITS)
	$(FPC) $(PTCFLAGS) -FU$(PTCUNITS) $(PTCSRC)/ptc.pp
	$(FPC) $(PTCFLAGS) -FU$(PTCUNITS) $(PTCSRC)/ptcwrapper.pp
	@echo ">> ptc rebuilt without DGA in $(PTCUNITS)/"

## debug : build with line info (-gl) for debugging with gdb (backtraces)
debug: plugins
	@mkdir -p build
	$(FPC) @$(CFG) -gl -O- $(MAIN)
	@echo ""
	@echo ">> Done (debug): $(BIN)  — use with: gdb ./$(BIN)"

## heaptrc : like 'debug' but also links the heap checker (-gh). Every block is
##           guarded, so a buffer overrun is reported when the block is freed,
##           together with the call trace of where it was allocated, and a leak
##           summary is printed on exit. Slower and noisier: use it to hunt
##           memory corruption, not for normal play.
heaptrc: plugins
	@mkdir -p build
	$(FPC) @$(CFG) -gl -gh -O- $(MAIN)
	@echo ""
	@echo ">> Done (heaptrc): $(BIN)"

## run : build and show the usage help (pass arguments with ARGS=...)
##       Example:  make run ARGS="3 /path/to/the/game"
run: build
	./$(BIN) $(ARGS)

## clean : remove build artifacts
clean:
	rm -f build/*.ppu build/*.o build/*.rsj build/*.a $(BIN)
	rm -rf $(PKGDIR) $(ABIDIR) $(PLUGDIR) $(X11TESTS) $(WLTESTS) $(CORETESTS) $(DIRECTUNITS)
	@echo ">> Cleaned."

## plugin-units : PIC build of the vendored ptc, ptcwrapper and ptcgraph for the
##                backend plugins, into build/plugins/units/. Same options as
##                the 'ptc' target plus -Cg; rebuilt only when VENDOR/ changes.
plugin-units: $(PLUGUNITS)/ptcgraph.ppu
$(PLUGUNITS)/ptcgraph.ppu: VENDOR/ptcgraph.pp $(wildcard VENDOR/*.inc) $(PTCSRC)/ptc.pp $(wildcard $(PTCSRC)/*.pp) $(wildcard $(PTCSRC)/x11/*.inc) $(wildcard $(PTCSRC)/core/*.inc)
	@mkdir -p $(PLUGUNITS)
	$(FPC) $(PTCFLAGS) -Cg -FU$(PLUGUNITS) $(PTCSRC)/ptc.pp
	$(FPC) $(PTCFLAGS) -Cg -FU$(PLUGUNITS) $(PTCSRC)/ptcwrapper.pp
	$(FPC) -O2 -Cg -FiVENDOR -Fu$(PLUGUNITS) -FU$(PLUGUNITS) VENDOR/ptcgraph.pp
	@echo ">> PIC units for the plugins in $(PLUGUNITS)/"

## direct-units : the pre-Phase-6 executable's ptcgraph, ptccrt and ptcmouse,
##                into build/directunits/ (reference for the 'direct' tests).
direct-units: $(DIRECTUNITS)/ptcmouse.ppu
$(DIRECTUNITS)/ptcmouse.ppu: $(PTCUNITS)/ptcwrapper.ppu VENDOR/ptcgraph.pp VENDOR/ptccrt.pp VENDOR/ptcmouse.pp $(wildcard VENDOR/*.inc)
	@mkdir -p $(DIRECTUNITS)
	$(FPCCORE) -FiVENDOR -Fu$(PTCUNITS) -FU$(DIRECTUNITS) VENDOR/ptcgraph.pp
	$(FPCCORE) -FiVENDOR -Fu$(PTCUNITS) -FU$(DIRECTUNITS) VENDOR/ptccrt.pp
	$(FPCCORE) -FiVENDOR -Fu$(PTCUNITS) -FU$(DIRECTUNITS) VENDOR/ptcmouse.pp
	@echo ">> reference units in $(DIRECTUNITS)/"

## x11-plugin : build the X11 backend plugin, build/plugins/libvpagraph-x11.so
x11-plugin: plugin-units
	@mkdir -p $(PLUGDIR)
	$(FPC) @$(PLUGCFG) -Fu$(PLUGUNITS) -FU$(PLUGDIR) -o$(X11PLUGIN) BACKENDS/X11/vpagraph_x11.lpr
	@echo ">> Done: $(X11PLUGIN)"

## wayland-units : PIC build of ptc (SDL3 console), ptcwrapper and ptcgraph for
##                 the Wayland plugin, into build/plugins/units-sdl3/.
wayland-units: $(WLUNITS)/ptcgraph.ppu
$(WLUNITS)/ptcgraph.ppu: VENDOR/ptcgraph.pp $(wildcard VENDOR/*.inc) $(PTCSRC)/ptc.pp $(wildcard $(PTCSRC)/*.pp) $(wildcard $(PTCSRC)/sdl/*.inc) $(wildcard $(PTCSRC)/core/*.inc) $(wildcard $(SDL3SRC)/*)
	@mkdir -p $(WLUNITS)
	$(FPC) $(WLPTCFLAGS) -Cg -FU$(WLUNITS) $(PTCSRC)/ptc.pp
	$(FPC) $(WLPTCFLAGS) -Cg -FU$(WLUNITS) $(PTCSRC)/ptcwrapper.pp
	$(FPC) -O2 -Cg -FiVENDOR -Fu$(WLUNITS) -FU$(WLUNITS) VENDOR/ptcgraph.pp
	@echo ">> PIC units for the Wayland plugin in $(WLUNITS)/"

## wayland-plugin : build the Wayland backend plugin,
##                  build/plugins/libvpagraph-wayland.so (needs libSDL3)
wayland-plugin: wayland-units
	@mkdir -p $(WLOBJ)
	$(FPC) @$(PLUGCFG) -dVPAG_WAYLAND -FuBACKENDS/X11 -Fu$(WLUNITS) -FU$(WLOBJ) $(SDL3LIB) -o$(WLPLUGIN) BACKENDS/WAYLAND/vpagraph_wayland.lpr
	@echo ">> Done: $(WLPLUGIN)"

## wayland-test : the Phase 8 acceptance tests of the Wayland plugin, under a
##                headless weston and WITHOUT a DISPLAY (needs weston):
##                - the scenes of scene-test drawn through the plugin must be
##                  byte-identical to the reference ptcgraph on X11 (T8B.10);
##                - graphapi-test through the core with VPA_GRAPH_BACKEND=wayland,
##                  byte-identical to 'uses ptcgraph';
##                - 20 Init/Shutdown cycles + dlclose, with and without cthreads
##                  in the harness, no leaks (R11, docs/threads-and-rtl.md);
##                - without a compositor Init returns VPAG_ERR_VIDEO and says why;
##                - the .so links libSDL3 and does NOT link libX11 (6.4).
wayland-test: wayland-plugin scene-test threads-test nodisplay-test graphapi-test
	@ldd $(WLPLUGIN) | grep -q libSDL3 || { echo ">> $(WLPLUGIN) does not link libSDL3"; exit 1; }
	@if ldd $(WLPLUGIN) | grep -q libX11; then echo ">> $(WLPLUGIN) links libX11"; exit 1; fi
	rm -rf $(WLTESTS) && mkdir -p $(WLTESTS)/scenes
	$(WESTON) ./$(X11TESTS)/scene_test_plugin $(abspath $(WLPLUGIN)) \
	  $(WLTESTS)/scenes/scene > $(WLTESTS)/scenes/log.txt 2>&1; \
	  grep -q '^scene_test: PASS' $(WLTESTS)/scenes/log.txt || { cat $(WLTESTS)/scenes/log.txt; exit 1; }
	@n=0; for f in $(WLTESTS)/scenes/scene0*; do \
	  cmp "$$f" "$(X11TESTS)/scenes/direct/$$(basename $$f)" || exit 1; n=$$((n+1)); done; \
	  test $$n -eq 10 || { echo ">> expected 10 dump files, got $$n"; exit 1; }; \
	  echo ">> $$n dump files identical to the X11 reference"
	@grep -E 'pixels|viewport|palette\[' $(WLTESTS)/scenes/log.txt | diff - $(X11TESTS)/scenes/direct/values.txt \
	  || { echo ">> GetPixel/GetViewSettings/GetRGBPalette differ from the X11 reference"; exit 1; }
	@mkdir -p $(WLTESTS)/core
	VPA_SCALE=1 VPA_GRAPH_BACKEND=wayland VPA_GRAPH_PLUGIN_DIR=$(abspath $(PLUGDIR)) VPA_GRAPH_DUMP=$(WLTESTS)/core/frame \
	  $(WESTON) ./$(CORETESTS)/graphapi_test_core > $(WLTESTS)/core/log.txt 2>&1; \
	  grep -q '^graphapi_test: PASS' $(WLTESTS)/core/log.txt || { cat $(WLTESTS)/core/log.txt; exit 1; }
	@n=0; for f in $(WLTESTS)/core/frame*; do \
	  cmp "$$f" "$(CORETESTS)/out/direct/$$(basename $$f)" || exit 1; n=$$((n+1)); done; \
	  test $$n -eq 10 || { echo ">> expected 10 dump files, got $$n"; exit 1; }; \
	  echo ">> core + Wayland plugin (VPA_GRAPH_BACKEND=wayland): $$n dump files identical to ptcgraph"
	@for t in threads_test threads_test_ct; do \
	  HEAPTRC=log=$(WLTESTS)/$$t.heaptrc $(WESTON) ./$(X11TESTS)/$$t $(abspath $(WLPLUGIN)) 20 \
	    > $(WLTESTS)/$$t.log 2>&1 || { cat $(WLTESTS)/$$t.log; exit 1; }; \
	  grep -q '^0 unfreed memory blocks' $(WLTESTS)/$$t.heaptrc \
	    || { echo ">> heaptrc reports leaks, see $(WLTESTS)/$$t.heaptrc"; exit 1; }; \
	done; echo ">> 2 x 20 Init/Shutdown cycles + dlclose, no leaks"
	@mkdir -p $(WLTESTS)/empty-runtime-dir
	env -u DISPLAY -u WAYLAND_DISPLAY XDG_RUNTIME_DIR=$(abspath $(WLTESTS))/empty-runtime-dir \
	  HEAPTRC=log=$(WLTESTS)/nodisplay_test.heaptrc \
	  ./$(X11TESTS)/nodisplay_test $(abspath $(WLPLUGIN)) 'wayland not available'
	@grep -q '^0 unfreed memory blocks' $(WLTESTS)/nodisplay_test.heaptrc \
	  || { echo ">> heaptrc reports leaks, see $(WLTESTS)/nodisplay_test.heaptrc"; exit 1; }
	@echo ">> wayland-test passed"

## plugins : build the backend plugins of a default build (today: x11; the
##           Wayland plugin is still opt-in, 'make wayland-plugin', until Phase 12)
plugins: x11-plugin

## threads-test : the T5.9 experiment (docs/threads-and-rtl.md): load the X11
##                plugin from a harness built WITHOUT and WITH cthreads, cycle
##                Init/Shutdown 20 times under Xvfb, dlclose, and check the
##                harness heap. Both variants must print PASS and leak nothing.
threads-test: x11-plugin
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -gh -FiGRAPH -FU$(X11TESTS) -o$(X11TESTS)/threads_test TESTS/x11/threads_test.lpr
	$(FPC) -MOBJFPC -gl -gh -FiGRAPH -FU$(X11TESTS) -o$(X11TESTS)/threads_test_ct -dUSE_CTHREADS TESTS/x11/threads_test.lpr
	@for t in threads_test threads_test_ct; do \
	  rm -f $(X11TESTS)/$$t.heaptrc; \
	  HEAPTRC=log=$(X11TESTS)/$$t.heaptrc xvfb-run -a -s "-screen 0 1024x768x24" \
	    ./$(X11TESTS)/$$t $(abspath $(X11PLUGIN)) 20 || exit 1; \
	  grep -q '^0 unfreed memory blocks' $(X11TESTS)/$$t.heaptrc \
	    || { echo ">> heaptrc reports leaks, see $(X11TESTS)/$$t.heaptrc"; exit 1; }; \
	done
	@echo ">> threads-test passed, no leaks"

## nodisplay-test : T5.5b: Init of the X11 plugin WITHOUT a DISPLAY must return
##                  VPAG_ERR_VIDEO (not abort the process), Shutdown must still
##                  be idempotent and dlclose must not deadlock. No Xvfb needed.
nodisplay-test: x11-plugin
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -gh -FiGRAPH -FU$(X11TESTS) -o$(X11TESTS)/nodisplay_test TESTS/x11/nodisplay_test.lpr
	rm -f $(X11TESTS)/nodisplay_test.heaptrc
	env -u DISPLAY HEAPTRC=log=$(X11TESTS)/nodisplay_test.heaptrc \
	  ./$(X11TESTS)/nodisplay_test $(abspath $(X11PLUGIN))
	@grep -q '^0 unfreed memory blocks' $(X11TESTS)/nodisplay_test.heaptrc \
	  || { echo ">> heaptrc reports leaks, see $(X11TESTS)/nodisplay_test.heaptrc"; exit 1; }
	@echo ">> nodisplay-test passed, no leaks"

## window-test : T5.6/T5.7: the T2.10 window block of the X11 plugin under Xvfb:
##               GetScreenSize before Init, window size per ScalePercent, keyboard
##               focus, _NET_WM_STATE_FULLSCREEN set/cleared, Suspend/Resume.
window-test: x11-plugin
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -gh -FiGRAPH -FU$(X11TESTS) -o$(X11TESTS)/window_test TESTS/x11/window_test.lpr
	rm -f $(X11TESTS)/window_test.heaptrc
	HEAPTRC=log=$(X11TESTS)/window_test.heaptrc xvfb-run -a -s "-screen 0 1600x1200x24" \
	  ./$(X11TESTS)/window_test $(abspath $(X11PLUGIN))
	@grep -q '^0 unfreed memory blocks' $(X11TESTS)/window_test.heaptrc \
	  || { echo ">> heaptrc reports leaks, see $(X11TESTS)/window_test.heaptrc"; exit 1; }
	@echo ">> window-test passed, no leaks"

## input-test : T5.8: the T2.11 keyboard/mouse block of the X11 plugin under Xvfb,
##              with xdotool injecting keys and mouse at 200% scale: events in
##              surface coordinates, key codes and Unicode, modifiers, Inside bit,
##              SetMousePos, ShowMouse and WM_DELETE_WINDOW -> CLOSE.
input-test: x11-plugin
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -gh -FiGRAPH -FU$(X11TESTS) -o$(X11TESTS)/input_test TESTS/x11/input_test.lpr
	rm -f $(X11TESTS)/input_test.heaptrc
	HEAPTRC=log=$(X11TESTS)/input_test.heaptrc xvfb-run -a -s "-screen 0 1600x1200x24" \
	  ./$(X11TESTS)/input_test $(abspath $(X11PLUGIN))
	@grep -q '^0 unfreed memory blocks' $(X11TESTS)/input_test.heaptrc \
	  || { echo ">> heaptrc reports leaks, see $(X11TESTS)/input_test.heaptrc"; exit 1; }
	@echo ">> input-test passed, no leaks"

## deps-test : T5.10: the plugin links libX11 and the harness that loads it
##             (scene_test_plugin, built by scene-test) does not.
deps-test: x11-plugin $(X11TESTS)/scene_test_plugin
	ldd $(X11PLUGIN) | grep -q libX11 || { echo ">> $(X11PLUGIN) does not link libX11"; exit 1; }
	@if readelf -d $(X11TESTS)/scene_test_plugin | grep -q libX11; then \
	  echo ">> $(X11TESTS)/scene_test_plugin links libX11"; exit 1; fi
	@echo ">> deps-test passed: the .so needs libX11, the harness that loads it does not"

## scene-test : T5.11, the acceptance criterion of Phase 5: the same scenes drawn
##              through the plugin (loaded with the real GRAPH/vpagraph_loader) and
##              directly against the reference ptcgraph (build/directunits)
##              must dump byte-identical frames and palettes.
$(X11TESTS)/scene_test_plugin: TESTS/x11/scene_test.lpr $(wildcard GRAPH/*)
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -FiGRAPH -FuGRAPH -FU$(X11TESTS) -o$@ TESTS/x11/scene_test.lpr
scene-test: x11-plugin direct-units $(X11TESTS)/scene_test_plugin
	$(FPC) -MOBJFPC -gl -dDIRECT -FiGRAPH -Fu$(DIRECTUNITS) -Fu$(PTCUNITS) -FU$(X11TESTS) -o$(X11TESTS)/scene_test_direct TESTS/x11/scene_test.lpr
	rm -rf $(X11TESTS)/scenes && mkdir -p $(X11TESTS)/scenes/plugin $(X11TESTS)/scenes/direct
	xvfb-run -a -s "-screen 0 1024x768x24" ./$(X11TESTS)/scene_test_plugin $(abspath $(X11PLUGIN)) \
	  $(X11TESTS)/scenes/plugin/scene > $(X11TESTS)/scenes/plugin/log.txt 2>&1; \
	  grep -v '^VPA: volcado' $(X11TESTS)/scenes/plugin/log.txt; grep -q '^scene_test: PASS' $(X11TESTS)/scenes/plugin/log.txt
	xvfb-run -a -s "-screen 0 1024x768x24" ./$(X11TESTS)/scene_test_direct - \
	  $(X11TESTS)/scenes/direct/scene > $(X11TESTS)/scenes/direct/log.txt 2>&1; \
	  grep -v '^VPA: volcado' $(X11TESTS)/scenes/direct/log.txt; grep -q '^scene_test: PASS' $(X11TESTS)/scenes/direct/log.txt
	@n=0; for f in $(X11TESTS)/scenes/plugin/scene*; do \
	  cmp "$$f" "$(X11TESTS)/scenes/direct/$$(basename $$f)" || exit 1; n=$$((n+1)); done; \
	  test $$n -eq 10 || { echo ">> expected 10 dump files, got $$n"; exit 1; }; \
	  echo ">> $$n dump files identical"
	@grep -E 'pixels|viewport|palette\[' $(X11TESTS)/scenes/plugin/log.txt > $(X11TESTS)/scenes/plugin/values.txt; \
	  grep -E 'pixels|viewport|palette\[' $(X11TESTS)/scenes/direct/log.txt > $(X11TESTS)/scenes/direct/values.txt; \
	  diff $(X11TESTS)/scenes/plugin/values.txt $(X11TESTS)/scenes/direct/values.txt \
	  || { echo ">> GetPixel/GetViewSettings/GetRGBPalette differ between variants"; exit 1; }
	@echo ">> scene-test passed: plugin and direct ptcgraph are pixel-identical"

## graphapi-test : T6.2, and the dress rehearsal of T6.5. One -Mtp source that
##                 draws the way VPA does, built twice: 'uses vpagraph' (core +
##                 plugin) and 'uses ptcgraph' (-dDIRECT). That one word is the
##                 only difference, and the dumps must be byte-identical.
graphapi-test: x11-plugin direct-units
	@mkdir -p $(CORETESTS)/core $(CORETESTS)/direct
	$(FPCCORE) -FuGRAPH -FiGRAPH -FU$(CORETESTS)/core -o$(CORETESTS)/graphapi_test_core TESTS/vpagraph/graphapi_test.pas
	$(FPCCORE) -dDIRECT -Fu$(DIRECTUNITS) -Fu$(PTCUNITS) -FU$(CORETESTS)/direct -o$(CORETESTS)/graphapi_test_direct TESTS/vpagraph/graphapi_test.pas
	rm -rf $(CORETESTS)/out && mkdir -p $(CORETESTS)/out/core $(CORETESTS)/out/direct
	VPA_SCALE=1 VPA_GRAPH_BACKEND=x11 VPA_GRAPH_PLUGIN_DIR=$(abspath $(PLUGDIR)) VPA_GRAPH_DUMP=$(CORETESTS)/out/core/frame \
	  xvfb-run -a -s "-screen 0 1024x768x24" ./$(CORETESTS)/graphapi_test_core > $(CORETESTS)/out/core/log.txt 2>&1; \
	  grep -v '^VPA: volcado' $(CORETESTS)/out/core/log.txt; grep -q '^graphapi_test: PASS' $(CORETESTS)/out/core/log.txt
	VPA_SCALE=1 VPA_GRAPH_DUMP=$(CORETESTS)/out/direct/frame \
	  xvfb-run -a -s "-screen 0 1024x768x24" ./$(CORETESTS)/graphapi_test_direct > $(CORETESTS)/out/direct/log.txt 2>&1; \
	  grep -q '^graphapi_test: PASS' $(CORETESTS)/out/direct/log.txt
	@n=0; for f in $(CORETESTS)/out/core/frame*; do \
	  cmp "$$f" "$(CORETESTS)/out/direct/$$(basename $$f)" || exit 1; n=$$((n+1)); done; \
	  test $$n -eq 10 || { echo ">> expected 10 dump files, got $$n"; exit 1; }; \
	  echo ">> $$n dump files identical"
	@for v in core direct; do grep -E 'pixels|viewport|palette\[|imagesize' $(CORETESTS)/out/$$v/log.txt > $(CORETESTS)/out/$$v/values.txt; done; \
	  diff $(CORETESTS)/out/core/values.txt $(CORETESTS)/out/direct/values.txt \
	  || { echo ">> GetPixel/GetViewSettings/ImageSize/GetRGBPalette differ between variants"; exit 1; }
	@if readelf -d $(CORETESTS)/graphapi_test_core | grep -q 'libX11\|libpthread'; then \
	  echo ">> graphapi_test_core links libX11 or libpthread"; exit 1; fi
	@echo ">> graphapi-test passed: 'uses vpagraph' and 'uses ptcgraph' are pixel-identical"

## initgraph-test : T6.3. InitGraph of the core selects, loads and starts the
##                  backend: fallback only with 'auto' (a missing wayland plugin
##                  falls back to x11, and says why), none when forced, every
##                  reason reported, Init/CloseGraph repeatable, no leaks.
initgraph-test: x11-plugin
	@mkdir -p $(CORETESTS)/core
	$(FPCCORE) -gh -gl -FuGRAPH -FiGRAPH -FU$(CORETESTS)/core -o$(CORETESTS)/initgraph_test TESTS/vpagraph/initgraph_test.pas
	@T=./$(CORETESTS)/initgraph_test; L=$(CORETESTS)/initgraph; rm -f $$L.*; \
	export VPA_SCALE=1 VPA_GRAPH_PLUGIN_DIR=$(abspath $(PLUGDIR)); \
	unset VPA_GRAPH_BACKEND WAYLAND_DISPLAY XDG_SESSION_TYPE; \
	fail() { echo ">> initgraph-test: $$1"; exit 1; }; \
	HEAPTRC=log=$$L.auto.heaptrc xvfb-run -a $$T > $$L.auto 2>&1 || fail "auto under X failed"; \
	test "$$(grep -c '^backend x11' $$L.auto)" = 2 || fail "auto under X: expected x11 twice"; \
	grep -q '^detail' $$L.auto && fail "auto under X: unexpected detail"; \
	test "$$(grep -c '^after resume: pixel 14 result 0' $$L.auto)" = 2 || fail "RestoreCrtMode/SetGraphMode cycle"; \
	grep -q '^0 unfreed memory blocks' $$L.auto.heaptrc || fail "leaks, see $$L.auto.heaptrc"; \
	echo "  ok   auto with DISPLAY only: x11, no detail, suspend/resume, repeatable, no leaks"; \
	HEAPTRC=log=$$L.fallback.heaptrc WAYLAND_DISPLAY=wayland-0 xvfb-run -a $$T > $$L.fallback 2>&1 || fail "fallback failed"; \
	grep -q '^backend x11' $$L.fallback || fail "fallback: expected x11"; \
	grep -q '^detail: wayland: .*libvpagraph-wayland.so' $$L.fallback || fail "fallback: no reason for wayland"; \
	grep -q '^0 unfreed memory blocks' $$L.fallback.heaptrc || fail "leaks, see $$L.fallback.heaptrc"; \
	echo "  ok   auto with WAYLAND_DISPLAY and no wayland plugin: falls back to x11 and says why"; \
	HEAPTRC=log=$$L.forced.heaptrc VPA_GRAPH_BACKEND=wayland xvfb-run -a $$T > $$L.forced 2>&1 && fail "forced wayland succeeded"; \
	grep -q '^result -2' $$L.forced || fail "forced wayland: expected grNotDetected"; \
	grep -q '^backend x11' $$L.forced && fail "forced wayland fell back to x11"; \
	echo "  ok   forced wayland: no fallback"; \
	HEAPTRC=log=$$L.nodisplay.heaptrc DISPLAY= VPA_GRAPH_BACKEND=x11 $$T > $$L.nodisplay 2>&1 && fail "x11 without DISPLAY succeeded"; \
	grep -q '^detail: x11: .*Cannot open X display' $$L.nodisplay || fail "x11 without DISPLAY: reason missing"; \
	grep -q '^0 unfreed memory blocks' $$L.nodisplay.heaptrc || fail "leaks, see $$L.nodisplay.heaptrc"; \
	echo "  ok   forced x11 without DISPLAY: Init fails cleanly with the reason of ptc"; \
	DISPLAY= $$T > $$L.nosession 2>&1 && fail "no session succeeded"; \
	grep -q '^detail: .*both unset' $$L.nosession || fail "no session: reason missing"; \
	echo "  ok   auto with no session at all"; \
	VPA_GRAPH_BACKEND=bogus $$T > $$L.bogus 2>&1 && fail "bogus backend succeeded"; \
	grep -q '^detail: "bogus" is not valid' $$L.bogus || fail "bogus: reason missing"; \
	echo "  ok   unknown VPA_GRAPH_BACKEND"
	@echo ">> initgraph-test passed"

## coreinput-test : core half of T6.6/T6.7 (GRAPH/vpagraph_input.pas). One -Mtp
##                  source built twice: over the core + plugin, and over the
##                  ptccrt + ptcmouse the executable used before Phase 6. Both get the
##                  same xdotool keystrokes and pointer moves under Xvfb; every
##                  key word, LastKbdFlags, QuitNoSave and mouse state must
##                  match. The core variant also runs the synthetic checks that
##                  need no display and must not link libX11 or libpthread.
coreinput-test: x11-plugin direct-units
	@mkdir -p $(CORETESTS)/core $(CORETESTS)/direct $(CORETESTS)/out
	$(FPCCORE) -FuGRAPH -FiGRAPH -FU$(CORETESTS)/core -o$(CORETESTS)/input_test_core TESTS/vpagraph/input_test.pas
	$(FPCCORE) -dDIRECT -Fu$(DIRECTUNITS) -Fu$(PTCUNITS) -FU$(CORETESTS)/direct -o$(CORETESTS)/input_test_direct TESTS/vpagraph/input_test.pas
	@echo ">> running both variants under Xvfb (about two minutes)"
	@O=$(CORETESTS)/out; rm -f $$O/input_*.txt; \
	( VPA_SCALE=1 VPA_GRAPH_BACKEND=x11 VPA_GRAPH_PLUGIN_DIR=$(abspath $(PLUGDIR)) \
	  xvfb-run -a -s "-screen 0 1024x768x24" ./$(CORETESTS)/input_test_core > $$O/input_core.txt 2>&1 ) & \
	( VPA_SCALE=1 xvfb-run -a -s "-screen 0 1024x768x24" ./$(CORETESTS)/input_test_direct > $$O/input_direct.txt 2>&1 ) & \
	wait; \
	grep -v '^key \|^mouse ' $$O/input_core.txt; \
	grep -q '^input_test: PASS' $$O/input_core.txt || { echo ">> core variant failed, see $$O/input_core.txt"; exit 1; }; \
	grep -q '^input_test: PASS' $$O/input_direct.txt || { echo ">> direct variant failed, see $$O/input_direct.txt"; exit 1; }; \
	grep '^key \|^mouse ' $$O/input_core.txt | grep -v '^key r ' > $$O/input_core.seen; \
	grep '^key \|^mouse ' $$O/input_direct.txt > $$O/input_direct.seen; \
	n=$$(wc -l < $$O/input_core.seen); test $$n -ge 200 || { echo ">> only $$n key/mouse lines"; exit 1; }; \
	diff $$O/input_core.seen $$O/input_direct.seen || { echo ">> the core and ptccrt/ptcmouse disagree"; exit 1; }; \
	grep -q '^key r -> \$$0072 ' $$O/input_core.txt || { echo ">> no keyboard after Suspend/Resume"; exit 1; }; \
	echo ">> $$n key and mouse readings identical"
	@if readelf -d $(CORETESTS)/input_test_core | grep -q 'libX11\|libpthread'; then \
	  echo ">> input_test_core links libX11 or libpthread"; exit 1; fi
	@echo ">> coreinput-test passed"

## abi-plugins : build the six ABI test plugins (stub + five faulty ones) into
##               build/abi/, and check that vpagraph_abi.inc compiles both from
##               -Mtp and from objfpc with identical record sizes.
abi-plugins:
	@mkdir -p $(ABIDIR)
	@for p in $(ABIPLUGS); do \
	  echo "$(FPCPLUG) -o$(ABIDIR)/$$p.so TESTS/abi/$$p.lpr"; \
	  $(FPCPLUG) -o$(ABIDIR)/$$p.so TESTS/abi/$$p.lpr || exit 1; \
	done
	$(FPCTP) TESTS/abi/abi_tp.pas
	$(FPC) -MOBJFPC -FiGRAPH -FU$(ABIDIR) TESTS/abi/abi_objfpc.pas
	@echo ">> ABI test plugins built in $(ABIDIR)/"

## loader-test : build and run the dynamic loader harness (WAYLAND.md, Phase 3)
##               against the test plugins: loads the stub, rejects the five
##               faulty ones, and runs 100 load/unload cycles under heaptrc.
##               Exit status 0 means every check passed and nothing leaked.
loader-test: abi-plugins
	$(FPC) -MOBJFPC -gh -gl -Cg -FiGRAPH -FuGRAPH -FU$(ABIDIR) -FE$(ABIDIR) TESTS/abi/loader_test.lpr
	$(FPCTP) TESTS/abi/loader_tp.pas
	@cp -f $(ABIDIR)/stub_backend.so $(ABIDIR)/libvpagraph-stub.so
	@echo "esto no es una biblioteca" > $(ABIDIR)/no_es_un_so.txt
	@rm -f $(ABIDIR)/loader_test.heaptrc
	HEAPTRC=log=$(ABIDIR)/loader_test.heaptrc ./$(ABIDIR)/loader_test $(abspath $(ABIDIR))
	@grep -q '^0 unfreed memory blocks' $(ABIDIR)/loader_test.heaptrc \
	  || { echo ">> heaptrc reports leaks, see $(ABIDIR)/loader_test.heaptrc"; exit 1; }
	@echo ">> loader-test passed, no leaks ($(ABIDIR)/loader_test.heaptrc)"

## detect-test : build and run the backend detection harness (WAYLAND.md,
##               Phase 4, T4.6): the six-case matrix (auto/x11/wayland) x
##               (X11 session/Wayland session), the no-silent-degradation rule,
##               the auto fallback and the error cases. The sessions are
##               simulated with WAYLAND_DISPLAY/DISPLAY/XDG_SESSION_TYPE and the
##               plugins are copies of the stub, so it needs no display and no
##               real backend. Exit status 0 means every check passed.
detect-test: abi-plugins
	$(FPC) -MOBJFPC -gl -Cg -FiGRAPH -FuGRAPH -FU$(ABIDIR) -FE$(ABIDIR) TESTS/abi/detect_test.lpr
	$(FPCTP) TESTS/abi/loader_tp.pas
	@mkdir -p $(ABIDIR)/detect
	@cp -f $(ABIDIR)/stub_backend.so $(ABIDIR)/detect/stub_backend.so
	@cp -f $(ABIDIR)/stub_backend.so $(ABIDIR)/detect/libvpagraph-x11.so
	@cp -f $(ABIDIR)/stub_backend.so $(ABIDIR)/detect/libvpagraph-wayland.so
	./$(ABIDIR)/detect_test $(abspath $(ABIDIR)/detect)
	@echo ">> detect-test passed"

## hlp  : generate both help files from their VHLP sources:
##          VHLP/VPA.HHH      -> build/VPA.HLP      (English, the one VPA loads)
##          VHLP/VPA_RUS.HHH  -> build/VPA_RUS.HLP  (Russian)
##        (VHLPMAKE shares the VHLP unit with VPA, so it links the VPAGraph
##         core, but it never opens a window: no display and no plugin
##         needed.) Copy them to your game
##         folder (where you run VPA), just like the .DAT files. VPA always
##         reads VPA.HLP: to play with the Russian help, replace VPA.HLP with
##         VPA_RUS.HLP (see HOWTO).
hlp:
	@mkdir -p build
	$(FPC) @$(CFG) -obuild/vhlpmake VHLP/VHLPMAKE.PAS
	@cp -f VHLP/VPA.HHH VHLP/VPA_RUS.HHH build/
	@cd build && ./vhlpmake VPA.HHH && mv -f VPA.hlp VPA.HLP
	@cd build && ./vhlpmake VPA_RUS.HHH && mv -f VPA_RUS.hlp VPA_RUS.HLP
	@cd build && rm -f VPA.HHH VPA_RUS.HHH vhlpmake
	@echo ""
	@echo ">> Generated build/VPA.HLP and build/VPA_RUS.HLP — copy them to your game folder:"
	@echo "   cp build/VPA.HLP build/VPA_RUS.HLP ~/PLANETS/"

## data : build the VPA binary AND both help files, and assemble the
##        ready-to-ship package in build/vpa-linux_package/ : the freshly
##        compiled VPA, its plugins/ folder (the graphics backends: VPA does
##        not start without it), VPA.HLP and VPA_RUS.HLP, the EXAMPLES/ folder, and
##        DISTTABL.DAT, HOWTO.en.md, HOWTO.es.md, LICENSE.md, LITT_VPA.CHR,
##        MPL-2.0.txt and VPA.MSG.
data: build hlp
	@cp -f LITT_VPA.CHR build/ 2>/dev/null || true
	@rm -rf $(PKGDIR)
	@mkdir -p $(PKGDIR)
	@cp -f $(BIN) $(PKGDIR)/
	@mkdir -p $(PKGDIR)/plugins
	@cp -f $(PLUGDIR)/libvpagraph-*.so $(PKGDIR)/plugins/
	@cp -f build/VPA.HLP build/VPA_RUS.HLP $(PKGDIR)/
	@cp -a EXAMPLES $(PKGDIR)/
	@cp -f $(PKGFILES) $(PKGDIR)/
	@echo ""
	@echo ">> Package ready in $(PKGDIR)/ :"
	@echo "   VPA  plugins/  VPA.HLP  VPA_RUS.HLP  EXAMPLES/  $(PKGFILES)"
	@echo ">> Copy its contents to your game folder, e.g.:  cp -a $(PKGDIR)/. ~/PLANETS/"

## help : list the targets
help:
	@grep -E '^## ' Makefile | sed 's/## //'
