# ============================================================================
# Makefile — Port de VGA Planets Assistant (VPA) 3.67 a GNU/Linux (Free Pascal)
# Sustituye al MAKEFILE de Borland Make. Ver BUILD.md para requisitos y uso.
# ============================================================================

FPC  ?= fpc
CFG   = vpa.cfg
MAIN  = VPA/VPA.PAS
BIN   = build/VPA

# Backend ptc vendorizado y recompilado SIN la extension X11 DGA (ver VENDOR/ptc).
# Se recompila a build/ptcunits y vpa.cfg lo antepone al ptc del sistema, de modo
# que el binario no dependa de la obsoleta libXxf86dga (retirada de Arch).
PTCSRC   = VENDOR/ptc
PTCUNITS = build/ptcunits

.PHONY: all build clean run help hlp data ptc

all: build

## build : compila el ejecutable en build/VPA
build: ptc
	@mkdir -p build
	$(FPC) @$(CFG) $(MAIN)
	@cp -f VPA/LITT_VPA.CHR build/ 2>/dev/null || true
	@echo ""
	@echo ">> Listo: $(BIN)"

## ptc  : recompila el backend ptc SIN la extension DGA (evita depender de
##        libXxf86dga). Se reconstruye solo si cambia el fuente vendorizado.
##        Nota: ptc es codigo FPC normal (no -Mtp), por eso NO usa @vpa.cfg.
ptc: $(PTCUNITS)/ptc.ppu
$(PTCUNITS)/ptc.ppu: $(PTCSRC)/ptc.pp $(PTCSRC)/x11/x11extensions.inc
	@mkdir -p $(PTCUNITS)
	$(FPC) -O2 -Fi$(PTCSRC) -Fi$(PTCSRC)/x11 -Fi$(PTCSRC)/core -FU$(PTCUNITS) $(PTCSRC)/ptc.pp
	@echo ">> ptc recompilado sin DGA en $(PTCUNITS)/"

## debug : compila con info de linea (-gl) para depurar con gdb (backtraces)
debug: ptc
	@mkdir -p build
	$(FPC) @$(CFG) -gl -O- $(MAIN)
	@echo ""
	@echo ">> Listo (debug): $(BIN)  — usar con: gdb ./$(BIN)"

## run : compila y muestra la ayuda de uso (pasa argumentos con ARGS=...)
##       Ejemplo:  make run ARGS="3 /ruta/a/la/partida"
run: build
	./$(BIN) $(ARGS)

## clean : borra los artefactos de compilacion
clean:
	rm -f build/*.ppu build/*.o build/*.rsj build/*.a $(BIN)
	@echo ">> Limpiado."

## hlp  : genera el fichero de ayuda VPA.HLP desde VHLP/VPA.HHH
##        (VHLPMAKE enlaza el unit grafico, por eso necesita un display:
##         se usa xvfb-run para un display virtual). Copialo a tu carpeta
##         de partida (donde ejecutas VPA), igual que los ficheros .DAT.
hlp:
	@mkdir -p build
	$(FPC) @$(CFG) -obuild/vhlpmake VHLP/VHLPMAKE.PAS
	@cp VHLP/VPA.HHH build/VPA.HHH
	@cd build && (xvfb-run -a ./vhlpmake VPA.HHH || ./vhlpmake VPA.HHH) && mv -f VPA.hlp VPA.HLP && rm -f VPA.HHH vhlpmake
	@echo ""
	@echo ">> Generado build/VPA.HLP — copialo a tu carpeta de partida:  cp build/VPA.HLP ~/PLANETS/"

## data : reune en build/ los ficheros de datos de ejecucion (binario + VPA.HLP
##        + LITT_VPA.CHR) listos para copiar a tu carpeta de partida.
##        VPA.HLP se compila (regla 'hlp'); LITT_VPA.CHR es un dato estatico.
data: build hlp
	@cp -f VPA/LITT_VPA.CHR build/ 2>/dev/null || true
	@echo ""
	@echo ">> Datos de ejecucion en build/:  VPA  VPA.HLP  LITT_VPA.CHR"
	@echo ">> Copialos a tu carpeta de partida, p.ej.:  cp build/VPA build/VPA.HLP build/LITT_VPA.CHR ~/PLANETS/"

## help : lista los objetivos
help:
	@grep -E '^## ' Makefile | sed 's/## //'
