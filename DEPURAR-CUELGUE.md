# Cómo localizar el cuelgue con gdb

El binario se queda esperando una pulsación de tecla que no le llega. Para ver
**el punto exacto** del código donde espera, sacamos un *backtrace* con gdb sobre
una compilación con información de línea.

## 1. Compilar en modo debug
```sh
make clean
make debug          # compila con -gl (info de línea)
```

## 2. Ejecutar bajo gdb
(Si no tienes gdb: `sudo pacman -S gdb`.)
```sh
gdb ./build/VPA
```
Dentro de gdb:
```
(gdb) run 5 LUPUS4 /K
```
Deja que llegue a `Reading messages...` y se congele (igual que antes).

## 3. Interrumpir y sacar el backtrace
Con la ventana congelada, vuelve a la terminal de gdb y pulsa **Ctrl-C**
(eso pausa el programa, no lo mata). Luego:
```
(gdb) thread apply all bt
```
Eso imprime la pila de **todos los hilos**. Cópiame el resultado entero (será
parecido a una lista de `#0 ... #1 ... #2 ...` por cada hilo).

Si `thread apply all bt` diera mucho ruido, con el del hilo principal me vale:
```
(gdb) bt
```

## 4. Salir
```
(gdb) kill
(gdb) quit
```

Con ese backtrace veré la procedure y la línea Pascal exactas donde está esperando
(p. ej. un bucle de entrada, un `PressAnyKey`, o un aviso), y podré arreglar la
causa con precisión en vez de adivinar.
