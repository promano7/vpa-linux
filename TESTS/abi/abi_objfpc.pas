{ La otra mitad: el mismo fichero desde una unidad en modo objfpc, que es
  compilan los plugins. Ademas comprueba en tiempo de COMPILACION los tamanos
  de los tipos de la ABI: si alguno cambiase, aqui falla el build en vez de
  fallar en tiempo de ejecucion con dos RTL de por medio. }
unit abi_objfpc;
{$MODE OBJFPC}{$H+}
interface
{$I vpagraph_abi.inc}
implementation

{ Las tres estructuras tienen que medir lo mismo compiladas en modo TP (el
  ejecutable) y en modo objfpc (los plugins), o la ABI esta rota de nacimiento
  aunque los dos lados compilen. Estas comprobaciones estan a proposito en los
  DOS ficheros de prueba, con las mismas cifras, para que una diferencia de
  empaquetado entre modos rompa el build en vez de aparecer en ejecucion con
  dos RTL de por medio. Si un cambio legitimo de la ABI altera un tamano, se
  actualizan aqui Y en el otro fichero, y se sube VPAGRAPH_ABI_VERSION. }
{$IF SizeOf(TVPAGraphEvent) <> 72}      {$ERROR TVPAGraphEvent cambio de tamano}      {$ENDIF}
{$IF SizeOf(TVPAGraphInitParams) <> 32} {$ERROR TVPAGraphInitParams cambio de tamano} {$ENDIF}
{$IF SizeOf(TVPAGraphInterface) <> 440} {$ERROR TVPAGraphInterface cambio de tamano}  {$ENDIF}
{$IF SizeOf(TVPAGraphInt8) <> 1}  {$ERROR TVPAGraphInt8 no mide 1 byte}  {$ENDIF}
{$IF SizeOf(TVPAGraphInt16) <> 2} {$ERROR TVPAGraphInt16 no mide 2 bytes} {$ENDIF}
{$IF SizeOf(TVPAGraphInt32) <> 4} {$ERROR TVPAGraphInt32 no mide 4 bytes} {$ENDIF}
{$IF SizeOf(TVPAGraphUInt8) <> 1} {$ERROR TVPAGraphUInt8 no mide 1 byte}  {$ENDIF}
{$IF SizeOf(TVPAGraphUInt16) <> 2}{$ERROR TVPAGraphUInt16 no mide 2 bytes}{$ENDIF}
{$IF SizeOf(TVPAGraphUInt32) <> 4}{$ERROR TVPAGraphUInt32 no mide 4 bytes}{$ENDIF}
{$IF SizeOf(TVPAGraphUInt64) <> 8}{$ERROR TVPAGraphUInt64 no mide 8 bytes}{$ENDIF}
{$IF SizeOf(TVPAGraphBool) <> 1}  {$ERROR TVPAGraphBool no mide 1 byte}  {$ENDIF}
end.
