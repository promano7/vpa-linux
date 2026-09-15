{ Comprueba que vpagraph_loader y vpagraph_errors se pueden consumir desde
  una unidad en modo Turbo Pascal, que es como se compila todo VPA (vpa.cfg:
  -Mtp). Las dos unidades declaran objfpc de forma local, igual que
  VENDOR/ptcgraph.pp, y esta es la prueba de que el precedente vale tambien
  para ellas (restriccion 2.3.1 de WAYLAND.md). No se ejecuta: basta con
  que compile sin avisos. }
unit loader_tp;
{$MODE TP}
interface
uses
  vpagraph_loader, vpagraph_errors;
implementation

{ Un shortstring de -Mtp entra donde el cargador espera AnsiString, y lo
  que el cargador devuelve cabe en un string de -Mtp. Es lo que hara
  GRAPH/vpagraph.pas en la Fase 6. }
function Prueba(const Backend: string): string;
var
  P      : TVPAGraphPlugin;
  Detail : AnsiString;
  Rc     : longint;
begin
  FillChar(P, SizeOf(P), 0);
  Rc := VPAGraph_LoadBackend(Backend, P, Detail);
  if Rc <> VPAGL_OK then
    Prueba := VPAGraph_FormatError(Rc, Detail, vglSpanish)
  else
  begin
    Prueba := VPAGraph_PluginFileName(Backend);
    VPAGraph_UnloadPlugin(P);
  end;
end;

end.
