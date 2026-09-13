{ Comprueba que GRAPH/vpagraph_abi.inc se puede consumir desde una unidad en
  modo Turbo Pascal, que es como se compila todo VPA (vpa.cfg: -Mtp). Es la
  mitad del criterio de aceptacion de la Fase 2. }
unit abi_tp;
{$MODE TP}
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
end.
