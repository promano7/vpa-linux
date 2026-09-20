{ ===========================================================================
  vpagraph_info.pas - El informe de --graph-info. Fase 4 de WAYLAND.md
  (T4.4).

  Herramienta de diagnostico numero uno para los informes de Alexander:
  imprime lo que dice el entorno de la sesion, el backend pedido, el plan de
  seleccion con sus motivos, el backend elegido con la ruta del plugin, la
  version de ABI y la del backend, y los motivos de los que se descartaron.
  Todo SIN abrir ninguna ventana: carga y valida el plugin, lo consulta y lo
  descarga; nunca llama a Init.

  El "controlador de video subyacente" que pide T4.4 no tiene campo propio
  en la ABI v1 y no se puede preguntar sin Init, asi que se acordo que cada
  plugin lo declare en BackendVersion (por ejemplo "1.0 (ptcgraph/PTCPas)")
  y que aqui se imprima ademas el entorno de sesion completo.

  Salida en ingles, como el resto de la consola de VPA. Devuelve el codigo
  de salida del proceso: 0 si se eligio un backend, 1 si no.

  Modo objfpc de forma local; se consume desde VPAINIT (-Mtp).
  =========================================================================== }
unit vpagraph_info;

{$MODE OBJFPC}{$H+}

interface

{ Escribe el informe en Output y devuelve 0 (backend elegido) o 1 (no). }
function VPAGraph_PrintGraphInfo: Integer;

implementation

uses
  vpagraph_loader, vpagraph_detect, vpagraph_errors;

{$I vpagraph_abi.inc}

function ShowEnv(const Value: AnsiString): AnsiString;
begin
  if Value = '' then Result := '(unset)' else Result := Value;
end;

function PCharToStr(P: PAnsiChar): AnsiString;
begin
  if P = nil then Result := '' else Result := AnsiString(P);
end;

{ Escribe un Detail multilinea con dos espacios de sangria por linea. }
procedure WriteIndented(const Detail: AnsiString);
var
  I, Start: Integer;
begin
  Start := 1;
  for I := 1 to Length(Detail) + 1 do
    if (I > Length(Detail)) or (Detail[I] = #10) then
    begin
      if I > Start then WriteLn('    ', Copy(Detail, Start, I - Start));
      Start := I + 1;
    end;
end;

function VPAGraph_PrintGraphInfo: Integer;
var
  Session : TVPAGraphSession;
  Plan    : TVPAGraphPlan;
  Plugin  : TVPAGraphPlugin;
  Chosen  : Integer;
  Detail  : AnsiString;
  Rc      : longint;
  I       : Integer;
begin
  VPAGraph_ReadSession(Session);
  FillChar(Plugin, SizeOf(Plugin), 0);
  Plugin.Path := '';

  WriteLn('VPA-Linux graphics backend information (--graph-info)');
  WriteLn;
  WriteLn('Session environment:');
  WriteLn('  ', VPAGD_ENV_WAYLAND, '      = ', ShowEnv(Session.WaylandDisplay));
  WriteLn('  ', VPAGD_ENV_X11, '              = ', ShowEnv(Session.Display));
  WriteLn('  ', VPAGD_ENV_SESSION, '     = ', ShowEnv(Session.SessionType));
  WriteLn('  ', VPAGD_ENV_BACKEND, '    = ', ShowEnv(Session.Requested));
  WriteLn('  ', VPAGL_ENV_PLUGIN_DIR, ' = ', ShowEnv(Session.PluginDir));
  WriteLn('  ', VPAGL_ENV_DEBUG, '      = ', ShowEnv(Session.Debug));
  WriteLn;

  Rc := VPAGraph_PlanBackends(VPAGraph_NormalizeRequest(Session.Requested),
    Session, Plan);
  WriteLn('Requested backend : ', Plan.Requested);
  if Rc <> VPAGL_OK then
  begin
    WriteLn('Backend order     : (none)');
    WriteLn;
    WriteLn('ERROR: ', VPAGraph_FormatError(Rc, Plan.Detail, vglEnglish));
    Result := 1;
    Exit;
  end;
  Write('Backend order     : ');
  for I := 0 to Plan.Count - 1 do
  begin
    if I > 0 then Write(', ');
    Write(Plan.Backend[I]);
  end;
  if Plan.Forced then Write(' (forced, no fallback)');
  WriteLn;
  for I := 0 to Plan.Count - 1 do
    WriteLn('  ', I + 1, '. ', Plan.Backend[I], ': ', Plan.Reason[I]);
  WriteLn;

  Rc := VPAGraph_SelectBackend(Plan, Plugin, Chosen, Detail);
  if Rc = VPAGL_OK then
  begin
    WriteLn('Selected backend  : ', Plan.Backend[Chosen]);
    WriteLn('  Plugin path     : ', Plugin.Path);
    WriteLn('  ABI version     : ', Plugin.Iface.ABIVersion,
      ' (executable expects ', VPAGRAPH_ABI_VERSION, ')');
    WriteLn('  Backend name    : ', PCharToStr(Plugin.Iface.BackendName));
    WriteLn('  Backend version : ', PCharToStr(Plugin.Iface.BackendVersion));
    if Detail <> '' then
    begin
      WriteLn('  Skipped before it:');
      WriteIndented(Detail);
    end;
    VPAGraph_UnloadPlugin(Plugin);
    Result := 0;
  end
  else
  begin
    WriteLn('Selected backend  : (none)');
    WriteLn;
    WriteLn('ERROR: ', VPAGraph_ErrorText(Rc, vglEnglish), ':');
    WriteIndented(Detail);
    Result := 1;
  end;
  WriteLn;
  WriteLn('Set ', VPAGL_ENV_DEBUG, '=1 to trace the plugin search on stderr.');
end;

end.
