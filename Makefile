# ============================================================================
# Makefile — Port of VGA Planets Assistant (VPA) 3.67 to GNU/Linux (Free Pascal)
# Replaces Borland Make's MAKEFILE. See BUILD.en.md for requirements and usage.
# ============================================================================

FPC  ?= fpc
CFG   = vpa.cfg
MAIN  = VPA/VPA.PAS
BIN   = build/VPA

# Vendored ptc backend, recompiled WITHOUT the X11 DGA extension (see VENDOR/ptc).
# It is rebuilt into build/ptcunits and vpa.cfg puts it before the system ptc, so
# that the binary doesn't depend on the obsolete libXxf86dga (dropped by Arch).
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
X11TESTS  = build/x11

.PHONY: all build clean run help hlp data ptc debug heaptrc abi-plugins loader-test detect-test \
        plugin-units x11-plugin plugins threads-test nodisplay-test window-test input-test scene-test deps-test

# 'data' runs 'build' and 'hlp', and both drive fpc over the same build/
# directory: never run them concurrently, even with 'make -jN'.
.NOTPARALLEL:

all: build

## build : build the executable into build/VPA
build: ptc
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
debug: ptc
	@mkdir -p build
	$(FPC) @$(CFG) -gl -O- $(MAIN)
	@echo ""
	@echo ">> Done (debug): $(BIN)  — use with: gdb ./$(BIN)"

## heaptrc : like 'debug' but also links the heap checker (-gh). Every block is
##           guarded, so a buffer overrun is reported when the block is freed,
##           together with the call trace of where it was allocated, and a leak
##           summary is printed on exit. Slower and noisier: use it to hunt
##           memory corruption, not for normal play.
heaptrc: ptc
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
	rm -rf $(PKGDIR) $(ABIDIR) $(PLUGDIR) $(X11TESTS)
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

## x11-plugin : build the X11 backend plugin, build/plugins/libvpagraph-x11.so
x11-plugin: plugin-units
	@mkdir -p $(PLUGDIR)
	$(FPC) @$(PLUGCFG) -o$(X11PLUGIN) BACKENDS/X11/vpagraph_x11.lpr
	@echo ">> Done: $(X11PLUGIN)"

## plugins : build every backend plugin (today: x11)
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
##              directly against the executable's ptcgraph (build/ptcgraph.ppu)
##              must dump byte-identical frames and palettes.
$(X11TESTS)/scene_test_plugin: TESTS/x11/scene_test.lpr $(wildcard GRAPH/*)
	@mkdir -p $(X11TESTS)
	$(FPC) -MOBJFPC -gl -FiGRAPH -FuGRAPH -FU$(X11TESTS) -o$@ TESTS/x11/scene_test.lpr
scene-test: x11-plugin build $(X11TESTS)/scene_test_plugin
	$(FPC) -MOBJFPC -gl -dDIRECT -FiGRAPH -Fubuild -Fu$(PTCUNITS) -FU$(X11TESTS) -o$(X11TESTS)/scene_test_direct TESTS/x11/scene_test.lpr
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
##        (VHLPMAKE links the graphics unit, so it needs a display:
##         xvfb-run is used for a virtual display). Copy them to your game
##         folder (where you run VPA), just like the .DAT files. VPA always
##         reads VPA.HLP: to play with the Russian help, replace VPA.HLP with
##         VPA_RUS.HLP (see HOWTO).
hlp:
	@mkdir -p build
	$(FPC) @$(CFG) -obuild/vhlpmake VHLP/VHLPMAKE.PAS
	@cp -f VHLP/VPA.HHH VHLP/VPA_RUS.HHH build/
	@cd build && (xvfb-run -a ./vhlpmake VPA.HHH || ./vhlpmake VPA.HHH) && mv -f VPA.hlp VPA.HLP
	@cd build && (xvfb-run -a ./vhlpmake VPA_RUS.HHH || ./vhlpmake VPA_RUS.HHH) && mv -f VPA_RUS.hlp VPA_RUS.HLP
	@cd build && rm -f VPA.HHH VPA_RUS.HHH vhlpmake
	@echo ""
	@echo ">> Generated build/VPA.HLP and build/VPA_RUS.HLP — copy them to your game folder:"
	@echo "   cp build/VPA.HLP build/VPA_RUS.HLP ~/PLANETS/"

## data : build the VPA binary AND both help files, and assemble the
##        ready-to-ship package in build/vpa-linux_package/ : the freshly
##        compiled VPA, VPA.HLP and VPA_RUS.HLP, the EXAMPLES/ folder, and
##        DISTTABL.DAT, HOWTO.en.md, HOWTO.es.md, LICENSE.md, LITT_VPA.CHR,
##        MPL-2.0.txt and VPA.MSG.
data: build hlp
	@cp -f LITT_VPA.CHR build/ 2>/dev/null || true
	@rm -rf $(PKGDIR)
	@mkdir -p $(PKGDIR)
	@cp -f $(BIN) $(PKGDIR)/
	@cp -f build/VPA.HLP build/VPA_RUS.HLP $(PKGDIR)/
	@cp -a EXAMPLES $(PKGDIR)/
	@cp -f $(PKGFILES) $(PKGDIR)/
	@echo ""
	@echo ">> Package ready in $(PKGDIR)/ :"
	@echo "   VPA  VPA.HLP  VPA_RUS.HLP  EXAMPLES/  $(PKGFILES)"
	@echo ">> Copy its contents to your game folder, e.g.:  cp -a $(PKGDIR)/. ~/PLANETS/"

## help : list the targets
help:
	@grep -E '^## ' Makefile | sed 's/## //'
