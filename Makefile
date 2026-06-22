# ============================================================================
# Makefile — Port de VGA Planets Assistant (VPA) 3.67 a GNU/Linux (Free Pascal)
# Sustituye al MAKEFILE de Borland Make. Ver BUILD.md para requisitos y uso.
# ============================================================================

FPC  ?= fpc
CFG   = vpa.cfg
MAIN  = VPA/VPA.PAS
BIN   = build/VPA

.PHONY: all build clean run help

all: build

## build : compila el ejecutable en build/VPA
build:
	@mkdir -p build
	$(FPC) @$(CFG) $(MAIN)
	@echo ""
	@echo ">> Listo: $(BIN)"

## run : compila y muestra la ayuda de uso (pasa argumentos con ARGS=...)
##       Ejemplo:  make run ARGS="3 /ruta/a/la/partida"
run: build
	./$(BIN) $(ARGS)

## clean : borra los artefactos de compilacion
clean:
	rm -f build/*.ppu build/*.o build/*.rsj build/*.a $(BIN)
	@echo ">> Limpiado."

## help : lista los objetivos
help:
	@grep -E '^## ' Makefile | sed 's/## //'
