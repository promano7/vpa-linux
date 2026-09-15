{ Comprueba que vpagraph_loader, vpagraph_errors, vpagraph_detect y
  vpagraph_info se pueden consumir desde
  una unidad en modo Turbo Pascal, que es como se compila todo VPA (vpa.cfg:
  -Mtp). Las cuatro unidades declaran objfpc de forma local, igual que
  VENDOR/ptcgraph.pp, y esta es la prueba de que el precedente vale tambien
  para ellas (restriccion 2.3.1 de WAYLAND.md). No se ejecuta: basta con
  que compile sin avisos. }
unit loader_tp;
{$MODE TP}
interface
uses
  vpagraph_loader, vpagraph_errors, vpagraph_detect, vpagraph_info;
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

{ Lo que hara VPA.PAS con --graph-info y el nucleo de la Fase 6 con el plan:
  leer la sesion, planificar y recorrer el plan desde -Mtp. }
function Plan(const Requested: string): string;
var
  S  : TVPAGraphSession;
  P  : TVPAGraphPlan;
  Rc : longint;
begin
  VPAGraph_ReadSession(S);
  Rc := VPAGraph_PlanBackends(VPAGraph_NormalizeRequest(Requested), S, P);
  if Rc <> VPAGL_OK then Plan := VPAGraph_FormatError(Rc, P.Detail, vglEnglish)
  else Plan := P.Backend[0];
end;

function Informe: integer;
begin
  Informe := VPAGraph_PrintGraphInfo;
end;

end.
