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

.PHONY: all build clean run help hlp data ptc

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
##        libXxf86dga). Rebuilt only when the vendored source changes.
##        Note: ptc is plain FPC code (not -Mtp), so it does NOT use @vpa.cfg.
ptc: $(PTCUNITS)/ptc.ppu
$(PTCUNITS)/ptc.ppu: $(PTCSRC)/ptc.pp $(wildcard $(PTCSRC)/*.pp) $(wildcard $(PTCSRC)/x11/*.inc) $(wildcard $(PTCSRC)/x11/*.pp) $(wildcard $(PTCSRC)/core/*.inc) $(wildcard $(PTCSRC)/core/*.pp)
	@mkdir -p $(PTCUNITS)
	$(FPC) -O2 -Fi$(PTCSRC) -Fi$(PTCSRC)/x11 -Fi$(PTCSRC)/core -FU$(PTCUNITS) $(PTCSRC)/ptc.pp
	@echo ">> ptc rebuilt without DGA in $(PTCUNITS)/"

## debug : build with line info (-gl) for debugging with gdb (backtraces)
debug: ptc
	@mkdir -p build
	$(FPC) @$(CFG) -gl -O- $(MAIN)
	@echo ""
	@echo ">> Done (debug): $(BIN)  — use with: gdb ./$(BIN)"

## run : build and show the usage help (pass arguments with ARGS=...)
##       Example:  make run ARGS="3 /path/to/the/game"
run: build
	./$(BIN) $(ARGS)

## clean : remove build artifacts
clean:
	rm -f build/*.ppu build/*.o build/*.rsj build/*.a $(BIN)
	rm -rf $(PKGDIR)
	@echo ">> Cleaned."

## hlp  : generate the VPA.HLP help file from VHLP/VPA.HHH
##        (VHLPMAKE links the graphics unit, so it needs a display:
##         xvfb-run is used for a virtual display). Copy it to your game
##         folder (where you run VPA), just like the .DAT files.
hlp:
	@mkdir -p build
	$(FPC) @$(CFG) -obuild/vhlpmake VHLP/VHLPMAKE.PAS
	@cp VHLP/VPA.HHH build/VPA.HHH
	@cd build && (xvfb-run -a ./vhlpmake VPA.HHH || ./vhlpmake VPA.HHH) && mv -f VPA.hlp VPA.HLP && rm -f VPA.HHH vhlpmake
	@echo ""
	@echo ">> Generated build/VPA.HLP — copy it to your game folder:  cp build/VPA.HLP ~/PLANETS/"

## data : build BOTH the VPA binary and VPA.HLP, and assemble the ready-to-ship
##        package in build/vpa-linux_package/ : the freshly compiled VPA and
##        VPA.HLP, the EXAMPLES/ folder, and DISTTABL.DAT, HOWTO.en.md,
##        HOWTO.es.md, LICENSE.md, LITT_VPA.CHR, MPL-2.0.txt and VPA.MSG.
data: build hlp
	@cp -f LITT_VPA.CHR build/ 2>/dev/null || true
	@rm -rf $(PKGDIR)
	@mkdir -p $(PKGDIR)
	@cp -f $(BIN) $(PKGDIR)/
	@cp -f build/VPA.HLP $(PKGDIR)/
	@cp -a EXAMPLES $(PKGDIR)/
	@cp -f $(PKGFILES) $(PKGDIR)/
	@echo ""
	@echo ">> Package ready in $(PKGDIR)/ :"
	@echo "   VPA  VPA.HLP  EXAMPLES/  $(PKGFILES)"
	@echo ">> Copy its contents to your game folder, e.g.:  cp -a $(PKGDIR)/. ~/PLANETS/"

## help : list the targets
help:
	@grep -E '^## ' Makefile | sed 's/## //'
