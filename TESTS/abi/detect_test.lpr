{ detect_test - arnes de pruebas de la deteccion y seleccion de backend
  (T4.6 de WAYLAND.md).

  Uso:
    detect_test <directorio-con-los-.so>

  Espera en ese directorio dos copias del stub renombradas como
  libvpagraph-x11.so y libvpagraph-wayland.so (las crea el objetivo
  detect-test del Makefile). No hace falta ningun servidor grafico ni
  ningun plugin real: la sesion se SIMULA con WAYLAND_DISPLAY, DISPLAY y
  XDG_SESSION_TYPE, y la carga es solo carga (nunca Init), asi que el arnes
  corre en cualquier sitio, incluido un contenedor sin pantalla.

  Comprueba, en este orden:

    1. la matriz de T4.6: (auto / x11 / wayland) x (sesion X11 / sesion
       Wayland), seis casos, con los dos plugins presentes;
    2. la regla de no-degradacion silenciosa (T4.3): con el plugin Wayland
       ausente, VPA_GRAPH_BACKEND=wayland falla y NO carga X11, y al reves;
    3. el respaldo de auto (T4.2): sin el plugin Wayland, una sesion Wayland
       en auto cae a X11 y el detalle dice por que se descarto Wayland;
    4. el desempate de XDG_SESSION_TYPE cuando las dos variables de pantalla
       estan definidas;
    5. los casos sin sesion: ninguna variable, o solo XDG_SESSION_TYPE;
    6. un valor desconocido de VPA_GRAPH_BACKEND, mayusculas y espacios;
    7. que cuando nada carga el detalle acumula TODOS los motivos, uno por
       candidato del cargador y por backend del plan (T4.2, punto 4).

  Codigo de salida 0 si todo pasa. }
program detect_test;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, Classes, vpagraph_loader, vpagraph_detect, vpagraph_errors;

{$I vpagraph_abi.inc}

function setenv(Name, Value: PAnsiChar; Overwrite: longint): longint; cdecl; external 'c';
function unsetenv(Name: PAnsiChar): longint; cdecl; external 'c';

var
  Dir    : AnsiString;
  Failed : Integer = 0;
  Passed : Integer = 0;

procedure Check(Cond: Boolean; const What: AnsiString);
begin
  if Cond then
  begin
    Inc(Passed);
    WriteLn('  ok    ', What);
  end
  else
  begin
    Inc(Failed);
    WriteLn('  FALLO ', What);
  end;
end;

function CountLines(const S: AnsiString): Integer;
var
  I: Integer;
begin
  if S = '' then Exit(0);
  Result := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Result);
end;

{ SysUtils no trae copia de ficheros; con dos streams basta. }
procedure CopyFile(const Src, Dst: AnsiString);
var
  I, O: TFileStream;
begin
  I := TFileStream.Create(Src, fmOpenRead);
  try
    O := TFileStream.Create(Dst, fmCreate);
    try
      O.CopyFrom(I, 0);
    finally
      O.Free;
    end;
  finally
    I.Free;
  end;
end;

{ Deja el entorno en un estado conocido. '' = variable sin definir. }
procedure SetSession(const Wayland, Display, SessionType, Backend: AnsiString);
begin
  if Wayland = '' then unsetenv('WAYLAND_DISPLAY')
  else setenv('WAYLAND_DISPLAY', PAnsiChar(Wayland), 1);
  if Display = '' then unsetenv('DISPLAY')
  else setenv('DISPLAY', PAnsiChar(Display), 1);
  if SessionType = '' then unsetenv('XDG_SESSION_TYPE')
  else setenv('XDG_SESSION_TYPE', PAnsiChar(SessionType), 1);
  if Backend = '' then unsetenv('VPA_GRAPH_BACKEND')
  else setenv('VPA_GRAPH_BACKEND', PAnsiChar(Backend), 1);
end;

{ Sesion X11 tipica: DISPLAY, sin compositor. }
procedure X11Session(const Backend: AnsiString);
begin
  SetSession('', ':0', 'x11', Backend);
end;

{ Sesion Wayland tipica, con XWayland: las dos variables, y el tipo dice
  wayland. }
procedure WaylandSession(const Backend: AnsiString);
begin
  SetSession('wayland-0', ':1', 'wayland', Backend);
end;

{ Lee la sesion, planifica y selecciona. Devuelve el codigo, y en Plan,
  Chosen y Detail lo que hizo. Descarga el plugin si cargo. }
function Run(var Plan: TVPAGraphPlan; var Chosen: Integer;
  var Detail: AnsiString; var Path: AnsiString): longint;
var
  Session : TVPAGraphSession;
  Plugin  : TVPAGraphPlugin;
begin
  VPAGraph_ReadSession(Session);
  FillChar(Plugin, SizeOf(Plugin), 0);
  Plugin.Path := '';
  Path := '';
  Result := VPAGraph_PlanBackends(VPAGraph_NormalizeRequest(Session.Requested),
    Session, Plan);
  if Result <> VPAGL_OK then
  begin
    Chosen := -1;
    Detail := Plan.Detail;
    Exit;
  end;
  Result := VPAGraph_SelectBackend(Plan, Plugin, Chosen, Detail);
  if Result = VPAGL_OK then
  begin
    Path := Plugin.Path;
    VPAGraph_UnloadPlugin(Plugin);
  end;
end;

{ Un caso de la matriz: espera que se elija Expected y que el plan tenga
  ExpectedCount entradas. }
procedure Matrix(const Name, Expected: AnsiString; ExpectedCount: Integer;
  ExpectForced: Boolean);
var
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
  Rc     : longint;
begin
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGL_OK, Name + ': selecciona (' +
    VPAGraph_FormatError(Rc, Detail, vglEnglish) + ')');
  if Rc <> VPAGL_OK then Exit;
  Check(Plan.Backend[Chosen] = Expected, Name + ': elegido ' + Plan.Backend[Chosen] +
    ' (esperado ' + Expected + ')');
  Check(Plan.Count = ExpectedCount, Name + ': plan de ' + IntToStr(Plan.Count) +
    ' (esperado ' + IntToStr(ExpectedCount) + ')');
  Check(Plan.Forced = ExpectForced, Name + ': Forced = ' + BoolToStr(Plan.Forced, True));
  Check(Path = Dir + '/' + VPAGraph_PluginFileName(Expected),
    Name + ': ruta ' + Path);
  Check(Detail = '', Name + ': sin descartes previos');
end;

procedure TestMatrix;
begin
  WriteLn('[1] matriz (auto/x11/wayland) x (sesion X11/sesion Wayland)');
  X11Session('');            Matrix('X11 + auto',         'x11',     1, False);
  X11Session('x11');         Matrix('X11 + x11',          'x11',     1, True);
  X11Session('wayland');     Matrix('X11 + wayland',      'wayland', 1, True);
  WaylandSession('');        Matrix('Wayland + auto',     'wayland', 2, False);
  WaylandSession('x11');     Matrix('Wayland + x11',      'x11',     1, True);
  WaylandSession('wayland'); Matrix('Wayland + wayland',  'wayland', 1, True);
end;

procedure TestNoSilentDegradation;
var
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
  Rc     : longint;
begin
  WriteLn('[2] no-degradacion silenciosa (T4.3), sin libvpagraph-wayland.so');
  DeleteFile(Dir + '/libvpagraph-wayland.so');

  WaylandSession('wayland');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGD_ERR_ALL_FAILED, 'wayland forzado sin plugin: VPAGD_ERR_ALL_FAILED');
  Check(Chosen = -1, 'wayland forzado sin plugin: nada elegido (no cae a X11)');
  Check(Plan.Count = 1, 'wayland forzado: el plan solo tiene wayland');
  Check(Pos('does not exist', Detail) > 0, 'el detalle dice que el .so no existe');
  Check(Pos('forced by VPA_GRAPH_BACKEND', Detail) > 0,
    'el detalle dice que no se probo otro backend por estar forzado');
  Check(Pos('x11', Detail) = 0, 'el detalle no menciona x11');
  WriteLn('        ', VPAGraph_FormatError(Rc, Detail, vglEnglish));

  X11Session('wayland');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGD_ERR_ALL_FAILED) and (Chosen = -1),
    'wayland forzado en sesion X11 sin plugin: falla, no cae a X11');

  { Y al reves, con el plugin X11 ausente y el Wayland de vuelta. }
  CopyFile(Dir + '/stub_backend.so', Dir + '/libvpagraph-wayland.so');
  DeleteFile(Dir + '/libvpagraph-x11.so');
  WaylandSession('x11');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGD_ERR_ALL_FAILED) and (Chosen = -1),
    'x11 forzado en sesion Wayland sin plugin X11: falla, no cae a Wayland');
  Check(Pos('wayland', LowerCase(Detail)) = 0, 'el detalle no menciona wayland');
  CopyFile(Dir + '/stub_backend.so', Dir + '/libvpagraph-x11.so');
end;

procedure TestAutoFallback;
var
  Cands  : TVPAGraphCandidates;
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
  Rc     : longint;
begin
  WriteLn('[3] respaldo de auto (T4.2), sin libvpagraph-wayland.so');
  VPAGraph_ResolvePluginPath('wayland', Cands);
  DeleteFile(Dir + '/libvpagraph-wayland.so');
  WaylandSession('');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGL_OK, 'sesion Wayland en auto: selecciona');
  Check((Chosen = 1) and (Plan.Backend[Chosen] = 'x11'), 'cae a x11 (segundo del plan)');
  Check(Pos('wayland: ', Detail) = 1, 'el detalle empieza por el motivo de wayland');
  Check(CountLines(Detail) = Cands.Count, 'un motivo por candidato del cargador (' +
    IntToStr(CountLines(Detail)) + ' lineas, ' + IntToStr(Cands.Count) + ' candidatos)');
  WriteLn('        descartado: ', StringReplace(Detail, LineEnding, ' | ', [rfReplaceAll]));

  { Sin ninguno de los dos: todos los motivos, de los dos backends. }
  DeleteFile(Dir + '/libvpagraph-x11.so');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGD_ERR_ALL_FAILED, 'sin ningun plugin: VPAGD_ERR_ALL_FAILED');
  Check(CountLines(Detail) = 2 * Cands.Count, 'todos los motivos acumulados, ' +
    IntToStr(Cands.Count) + ' por backend (' + IntToStr(CountLines(Detail)) + ')');
  Check((Pos('wayland: ', Detail) > 0) and (Pos('x11: ', Detail) > 0),
    'el detalle nombra los dos backends');
  CopyFile(Dir + '/stub_backend.so', Dir + '/libvpagraph-wayland.so');
  CopyFile(Dir + '/stub_backend.so', Dir + '/libvpagraph-x11.so');
end;

procedure TestTieBreak;
var
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
begin
  WriteLn('[4] desempate con XDG_SESSION_TYPE');
  SetSession('wayland-0', ':0', 'x11', '');
  Run(Plan, Chosen, Detail, Path);
  Check((Plan.Count = 2) and (Plan.Backend[0] = 'x11') and (Plan.Backend[1] = 'wayland'),
    'ambas definidas + x11: [x11, wayland]');
  SetSession('wayland-0', ':0', 'wayland', '');
  Run(Plan, Chosen, Detail, Path);
  Check((Plan.Count = 2) and (Plan.Backend[0] = 'wayland') and (Plan.Backend[1] = 'x11'),
    'ambas definidas + wayland: [wayland, x11]');
  SetSession('wayland-0', ':0', '', '');
  Run(Plan, Chosen, Detail, Path);
  Check((Plan.Count = 2) and (Plan.Backend[0] = 'wayland'),
    'ambas definidas sin tipo: Wayland primero');
  SetSession('wayland-0', ':0', 'X11', '');
  Run(Plan, Chosen, Detail, Path);
  Check(Plan.Backend[0] = 'x11', 'XDG_SESSION_TYPE se compara sin distinguir mayusculas');
  SetSession('wayland-0', '', 'x11', '');
  Run(Plan, Chosen, Detail, Path);
  Check((Plan.Count = 1) and (Plan.Backend[0] = 'wayland'),
    'solo WAYLAND_DISPLAY, aunque el tipo diga x11: [wayland] (sin DISPLAY no hay X)');
end;

procedure TestNoSession;
var
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
  Rc     : longint;
begin
  WriteLn('[5] sin sesion');
  SetSession('', '', '', '');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGD_ERR_NO_SESSION, 'nada definido: VPAGD_ERR_NO_SESSION');
  Check(Pos('both unset', Detail) > 0, 'el detalle nombra las dos variables');
  WriteLn('        ', VPAGraph_FormatError(Rc, Detail, vglEnglish));
  SetSession('', '', 'tty', '');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGD_ERR_NO_SESSION) and (Pos('tty', Detail) > 0),
    'solo XDG_SESSION_TYPE=tty: error, y el detalle lo dice');
  SetSession('', '', 'wayland', '');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGL_OK) and (Plan.Backend[0] = 'wayland') and (Plan.Count = 1),
    'solo XDG_SESSION_TYPE=wayland: se intenta el socket por defecto');
  SetSession('', '', '', 'x11');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGL_OK) and Plan.Forced, 'x11 forzado sin sesion: se intenta igual (forzado manda)');
end;

procedure TestBadRequest;
var
  Plan   : TVPAGraphPlan;
  Chosen : Integer;
  Detail, Path : AnsiString;
  Rc     : longint;
begin
  WriteLn('[6] VPA_GRAPH_BACKEND');
  X11Session('vesa');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check(Rc = VPAGD_ERR_BAD_REQUEST, 'vesa: VPAGD_ERR_BAD_REQUEST');
  Check(Pos('auto, x11 or wayland', Detail) > 0, 'el detalle lista los valores validos');
  WriteLn('        ', VPAGraph_FormatError(Rc, Detail, vglEnglish));
  X11Session(' X11 ');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGL_OK) and (Plan.Requested = 'x11') and Plan.Forced,
    '" X11 " se normaliza a x11');
  X11Session('AUTO');
  Rc := Run(Plan, Chosen, Detail, Path);
  Check((Rc = VPAGL_OK) and (Plan.Requested = 'auto') and not Plan.Forced,
    'AUTO se normaliza a auto');
  Check(VPAGraph_NormalizeRequest('') = 'auto', 'vacio equivale a auto');
end;

begin
  if ParamCount < 1 then
  begin
    WriteLn('uso: detect_test <directorio-con-los-.so>');
    Halt(2);
  end;
  Dir := ExcludeTrailingPathDelimiter(ParamStr(1));
  if not FileExists(Dir + '/libvpagraph-x11.so') or
     not FileExists(Dir + '/libvpagraph-wayland.so') then
  begin
    WriteLn('faltan libvpagraph-x11.so / libvpagraph-wayland.so en ', Dir);
    Halt(2);
  end;
  { Solo se busca en Dir: asi el resultado no depende de lo que haya junto al
    ejecutable ni en el directorio de instalacion de la maquina. }
  setenv('VPA_GRAPH_PLUGIN_DIR', PAnsiChar(Dir), 1);
  WriteLn('detect_test: plugins en ', Dir);
  WriteLn;

  TestMatrix;
  TestNoSilentDegradation;
  TestAutoFallback;
  TestTieBreak;
  TestNoSession;
  TestBadRequest;

  WriteLn;
  WriteLn(Passed, ' comprobaciones correctas, ', Failed, ' fallidas');
  if Failed > 0 then Halt(1);
end.
