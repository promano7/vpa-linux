{ ===========================================================================
  vpagraph_detect.pas - Deteccion de la sesion grafica y seleccion del
  backend. Fase 4 de WAYLAND.md (T4.1 a T4.3).

  Esta unidad decide QUE backends intentar y EN QUE ORDEN; cargarlos es del
  cargador (vpagraph_loader.pas) y arrancarlos (Init) es del nucleo
  (GRAPH/vpagraph.pas, Fase 6). Aqui no se abre ninguna ventana.

  El resultado es un PLAN (TVPAGraphPlan): una lista ordenada de backends,
  con el motivo por el que cada uno esta en su puesto, y una marca Forced.
  El nucleo recorre el plan de principio a fin: carga, Init, y si Init falla
  pasa al siguiente SOLO si el plan no es forzado. Asi la regla de
  no-degradacion silenciosa (T4.3) queda garantizada por construccion: con
  VPA_GRAPH_BACKEND=wayland el plan tiene un unico backend y no hay a donde
  caer; el respaldo solo existe en modo auto.

  Deteccion automatica (T4.2), con W = WAYLAND_DISPLAY definida,
  X = DISPLAY definida y S = XDG_SESSION_TYPE en minusculas:

    W y X    -> [wayland, x11], salvo que S = 'x11', que invierte el orden.
                Es el caso normal de una sesion Wayland con XWayland, y
                tambien el de una sesion X11 con variables heredadas de un
                compositor: S desempata.
    solo W   -> [wayland]. Sin DISPLAY no hay servidor X al que conectar,
                asi que X11 no entra ni como respaldo.
    solo X   -> [x11]. Idem al reves.
    ni W ni X -> [wayland] si S = 'wayland' (libwayland usa el socket por
                defecto, wayland-0, cuando WAYLAND_DISPLAY no esta); si no,
                error VPAGD_ERR_NO_SESSION.

  Con VPA_GRAPH_BACKEND=x11 o =wayland el plan es ese backend y solo ese,
  sin mirar el entorno: si el usuario fuerza un backend en una sesion que
  no lo tiene, el fallo se le cuenta con su motivo, no se le cambia por
  otro backend.

  Todo texto que sale de aqui (motivos, detalles) esta en ingles, como el
  resto de la salida de consola de VPA.

  Modo objfpc de forma local, como vpagraph_loader.pas; sin SysUtils, por
  el mismo motivo que alli.
  =========================================================================== }
unit vpagraph_detect;

{$MODE OBJFPC}{$H+}

interface

uses
  vpagraph_loader;

{$I vpagraph_abi.inc}

const
  { --- Codigos de error de la seleccion ---
    Negativos y fuera del rango de la ABI (-1..-100) y del cargador
    (-1001..-1099). }
  VPAGD_ERR_BAD_REQUEST = -1101;  { VPA_GRAPH_BACKEND con un valor desconocido }
  VPAGD_ERR_NO_SESSION  = -1102;  { auto sin WAYLAND_DISPLAY, DISPLAY ni XDG_SESSION_TYPE=wayland }
  VPAGD_ERR_ALL_FAILED  = -1103;  { ningun backend del plan cargo }

  { Variables de entorno que entiende esta unidad. }
  VPAGD_ENV_BACKEND = 'VPA_GRAPH_BACKEND';
  VPAGD_ENV_WAYLAND = 'WAYLAND_DISPLAY';
  VPAGD_ENV_X11     = 'DISPLAY';
  VPAGD_ENV_SESSION = 'XDG_SESSION_TYPE';

  { Valores de VPA_GRAPH_BACKEND. Son tambien los nombres de fichero del
    cargador: 'x11' -> libvpagraph-x11.so. }
  VPAGD_AUTO    = 'auto';
  VPAGD_X11     = 'x11';
  VPAGD_WAYLAND = 'wayland';

  { Backends que puede contener un plan. Hoy dos; KMS/DRM o framebuffer
    (seccion 1.1 de WAYLAND.md) entrarian aqui. }
  VPAGD_MAX_PLAN = 2;

type
  { Lo que dice el entorno de la sesion grafica, tal cual (sin normalizar):
    es lo que --graph-info ensena y lo que Alexander no sabe contarnos. }
  TVPAGraphSession = record
    WaylandDisplay : AnsiString;   { $WAYLAND_DISPLAY o '' }
    Display        : AnsiString;   { $DISPLAY o '' }
    SessionType    : AnsiString;   { $XDG_SESSION_TYPE o '' }
    Requested      : AnsiString;   { $VPA_GRAPH_BACKEND o '' }
    PluginDir      : AnsiString;   { $VPA_GRAPH_PLUGIN_DIR o '' }
    Debug          : AnsiString;   { $VPA_GRAPH_DEBUG o '' }
  end;

  { Plan de seleccion. Error = VPAGL_OK con Count >= 1, o un VPAGD_ERR_* con
    Count = 0 y la explicacion en Detail. }
  TVPAGraphPlan = record
    Requested : AnsiString;   { 'auto', 'x11' o 'wayland', ya normalizado }
    Forced    : Boolean;      { True si Requested <> 'auto': sin respaldo (T4.3) }
    Count     : Integer;
    Backend   : array[0..VPAGD_MAX_PLAN - 1] of AnsiString;
    Reason    : array[0..VPAGD_MAX_PLAN - 1] of AnsiString;  { por que esta ahi }
    Error     : longint;
    Detail    : AnsiString;
  end;

{ Lee las variables de entorno de la sesion. No falla nunca. }
procedure VPAGraph_ReadSession(var Session: TVPAGraphSession);

{ Normaliza el valor de VPA_GRAPH_BACKEND: minusculas y sin espacios; ''
  equivale a 'auto'. NO valida: eso lo hace VPAGraph_PlanBackends. }
function VPAGraph_NormalizeRequest(const Value: AnsiString): AnsiString;

{ --- T4.1 y T4.2: el plan ---

  Rellena Plan a partir de Requested (ya normalizado, ver arriba) y del
  entorno de Session. Devuelve Plan.Error. Con 'auto' aplica el algoritmo
  de la cabecera; con 'x11' o 'wayland' el plan es ese backend, forzado.
  Cualquier otro valor da VPAGD_ERR_BAD_REQUEST. }
function VPAGraph_PlanBackends(const Requested: AnsiString;
  const Session: TVPAGraphSession; var Plan: TVPAGraphPlan): longint;

{ --- T4.3: seleccion sin arrancar ---

  Recorre el plan y carga (solo carga: sin Init, sin ventana) el primer
  backend cuyo plugin carga y valida. Chosen recibe el indice del plan que
  se quedo, o -1. Detail acumula los motivos de cada backend descartado
  antes del elegido, uno por linea, tal como los da el cargador. Si ninguno
  carga devuelve VPAGD_ERR_ALL_FAILED con TODOS los motivos en Detail
  (T4.2, punto 4). Con un plan forzado solo hay un backend y por tanto no
  hay respaldo posible.

  Es lo que usa --graph-info. El nucleo (Fase 6) no debe usar esta funcion
  sino recorrer el plan el mismo con VPAGraph_LoadPlanEntry, porque entre
  cargar y decidir esta Init, que puede fallar y tambien cuenta como
  "falla" para el respaldo de T4.2. }
function VPAGraph_SelectBackend(const Plan: TVPAGraphPlan;
  var Plugin: TVPAGraphPlugin; var Chosen: Integer;
  var Detail: AnsiString): longint;

{ Carga el backend en la posicion Index del plan. Envoltorio de
  VPAGraph_LoadBackend que antepone el nombre del backend al detalle y deja
  traza del plan si VPA_GRAPH_DEBUG=1. }
function VPAGraph_LoadPlanEntry(const Plan: TVPAGraphPlan; Index: Integer;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;

implementation

{ Mismo getenv de libc que en el cargador, y por el mismo motivo: ver el
  entorno tal como esta AHORA, no la copia que el RTL tomo al arrancar (el
  arnes de pruebas cambia las variables en ejecucion). }
function c_getenv(Name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';

function GetEnv(const Name: AnsiString): AnsiString;
var
  P: PAnsiChar;
begin
  P := c_getenv(PAnsiChar(Name));
  if P = nil then Result := '' else Result := AnsiString(P);
end;

{ Minusculas ASCII y sin espacios en los extremos. Basta para valores de
  variables de entorno; no hace falta SysUtils. }
function LowerTrim(const S: AnsiString): AnsiString;
var
  A, B, I: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] in [' ', #9]) do Inc(A);
  while (B >= A) and (S[B] in [' ', #9]) do Dec(B);
  Result := Copy(S, A, B - A + 1);
  for I := 1 to Length(Result) do
    if Result[I] in ['A'..'Z'] then Inc(Result[I], 32);
end;

procedure AppendLine(var Detail: AnsiString; const S: AnsiString);
begin
  if S = '' then Exit;
  if Detail <> '' then Detail := Detail + LineEnding;
  Detail := Detail + S;
end;

function PCharToStr(P: PAnsiChar): AnsiString;
begin
  if P = nil then Result := '' else Result := AnsiString(P);
end;

{ ---------------------------------------------------------------------------
  Sesion
  --------------------------------------------------------------------------- }

procedure VPAGraph_ReadSession(var Session: TVPAGraphSession);
begin
  Session.WaylandDisplay := GetEnv(VPAGD_ENV_WAYLAND);
  Session.Display        := GetEnv(VPAGD_ENV_X11);
  Session.SessionType    := GetEnv(VPAGD_ENV_SESSION);
  Session.Requested      := GetEnv(VPAGD_ENV_BACKEND);
  Session.PluginDir      := GetEnv(VPAGL_ENV_PLUGIN_DIR);
  Session.Debug          := GetEnv(VPAGL_ENV_DEBUG);
end;

function VPAGraph_NormalizeRequest(const Value: AnsiString): AnsiString;
begin
  Result := LowerTrim(Value);
  if Result = '' then Result := VPAGD_AUTO;
end;

{ ---------------------------------------------------------------------------
  Plan (T4.1, T4.2, T4.3)
  --------------------------------------------------------------------------- }

procedure ClearPlan(var Plan: TVPAGraphPlan);
var
  I: Integer;
begin
  Plan.Requested := '';
  Plan.Forced := False;
  Plan.Count := 0;
  for I := 0 to VPAGD_MAX_PLAN - 1 do
  begin
    Plan.Backend[I] := '';
    Plan.Reason[I] := '';
  end;
  Plan.Error := VPAGL_OK;
  Plan.Detail := '';
end;

procedure AddToPlan(var Plan: TVPAGraphPlan; const Backend, Reason: AnsiString);
begin
  if Plan.Count >= VPAGD_MAX_PLAN then Exit;
  Plan.Backend[Plan.Count] := Backend;
  Plan.Reason[Plan.Count] := Reason;
  Inc(Plan.Count);
end;

function VPAGraph_PlanBackends(const Requested: AnsiString;
  const Session: TVPAGraphSession; var Plan: TVPAGraphPlan): longint;
var
  W, X     : Boolean;
  S        : AnsiString;
  ForcedBy : AnsiString;
  I        : Integer;
begin
  ClearPlan(Plan);
  Plan.Requested := Requested;

  { --- Forzado (T4.3): un backend, sin respaldo, sin mirar el entorno --- }
  if (Requested = VPAGD_X11) or (Requested = VPAGD_WAYLAND) then
  begin
    Plan.Forced := True;
    ForcedBy := 'forced by ' + VPAGD_ENV_BACKEND + '=' + Requested +
      ' (no fallback to any other backend)';
    AddToPlan(Plan, Requested, ForcedBy);
  end
  else if Requested <> VPAGD_AUTO then
  begin
    Plan.Error := VPAGD_ERR_BAD_REQUEST;
    Plan.Detail := '"' + Session.Requested + '" is not valid, use ' +
      VPAGD_AUTO + ', ' + VPAGD_X11 + ' or ' + VPAGD_WAYLAND;
  end
  else
  begin
    { --- Automatico (T4.2) --- }
    W := Session.WaylandDisplay <> '';
    X := Session.Display <> '';
    S := LowerTrim(Session.SessionType);
    if W and X then
    begin
      if S = VPAGD_X11 then
      begin
        AddToPlan(Plan, VPAGD_X11, VPAGD_ENV_X11 + ' and ' + VPAGD_ENV_WAYLAND +
          ' are both set; ' + VPAGD_ENV_SESSION + '=x11 breaks the tie');
        AddToPlan(Plan, VPAGD_WAYLAND, 'fallback: ' + VPAGD_ENV_WAYLAND +
          ' is set');
      end
      else
      begin
        if S = VPAGD_WAYLAND then
          AddToPlan(Plan, VPAGD_WAYLAND, VPAGD_ENV_WAYLAND + ' and ' +
            VPAGD_ENV_X11 + ' are both set; ' + VPAGD_ENV_SESSION +
            '=wayland breaks the tie')
        else
          AddToPlan(Plan, VPAGD_WAYLAND, VPAGD_ENV_WAYLAND + ' and ' +
            VPAGD_ENV_X11 + ' are both set; ' + VPAGD_ENV_SESSION +
            ' does not say x11, so Wayland goes first');
        AddToPlan(Plan, VPAGD_X11, 'fallback: ' + VPAGD_ENV_X11 + ' is set');
      end;
    end
    else if W then
      AddToPlan(Plan, VPAGD_WAYLAND, VPAGD_ENV_WAYLAND + ' is set and ' +
        VPAGD_ENV_X11 + ' is not (no X server to fall back to)')
    else if X then
      AddToPlan(Plan, VPAGD_X11, VPAGD_ENV_X11 + ' is set and ' +
        VPAGD_ENV_WAYLAND + ' is not (no Wayland compositor to fall back to)')
    else if S = VPAGD_WAYLAND then
      AddToPlan(Plan, VPAGD_WAYLAND, VPAGD_ENV_WAYLAND + ' and ' +
        VPAGD_ENV_X11 + ' are both unset, but ' + VPAGD_ENV_SESSION +
        '=wayland: trying the default Wayland socket')
    else
    begin
      Plan.Error := VPAGD_ERR_NO_SESSION;
      Plan.Detail := VPAGD_ENV_WAYLAND + ' and ' + VPAGD_ENV_X11 +
        ' are both unset';
      if S = '' then
        Plan.Detail := Plan.Detail + ' and ' + VPAGD_ENV_SESSION + ' is unset'
      else
        Plan.Detail := Plan.Detail + ' and ' + VPAGD_ENV_SESSION + '=' +
          Session.SessionType + ' is not a graphical session type';
    end;
  end;

  if VPAGraph_LoaderDebug then
  begin
    VPAGraph_Log('backend request: ' + Requested);
    for I := 0 to Plan.Count - 1 do
      VPAGraph_Log('  plan ' + Chr(Ord('1') + I) + ': ' + Plan.Backend[I] +
        ' (' + Plan.Reason[I] + ')');
    if Plan.Error <> VPAGL_OK then
      VPAGraph_Log('  no plan: ' + Plan.Detail);
  end;
  Result := Plan.Error;
end;

{ ---------------------------------------------------------------------------
  Seleccion sin arrancar (T4.3)
  --------------------------------------------------------------------------- }

function VPAGraph_LoadPlanEntry(const Plan: TVPAGraphPlan; Index: Integer;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;
var
  Name : AnsiString;
begin
  Detail := '';
  if (Index < 0) or (Index >= Plan.Count) then
  begin
    Detail := 'plan entry out of range';
    Result := VPAGD_ERR_ALL_FAILED;
    Exit;
  end;
  Result := VPAGraph_LoadBackend(Plan.Backend[Index], Plugin, Detail);
  if Result = VPAGL_OK then
  begin
    { El cargador no compara BackendName con el nombre del fichero: el
      arnes de la Fase 4 carga copias del stub renombradas. Se deja traza
      de la discrepancia, que en un plugin real seria un error de
      empaquetado. }
    Name := PCharToStr(Plugin.Iface.BackendName);
    if Name <> Plan.Backend[Index] then
      VPAGraph_Log('  note: ' + VPAGraph_PluginFileName(Plan.Backend[Index]) +
        ' identifies itself as backend "' + Name + '"');
  end
  else if Detail <> '' then
    Detail := Plan.Backend[Index] + ': ' + Detail;
end;

function VPAGraph_SelectBackend(const Plan: TVPAGraphPlan;
  var Plugin: TVPAGraphPlugin; var Chosen: Integer;
  var Detail: AnsiString): longint;
var
  I   : Integer;
  One : AnsiString;
  Rc  : longint;
begin
  Chosen := -1;
  Detail := '';
  if Plan.Error <> VPAGL_OK then
  begin
    Detail := Plan.Detail;
    Result := Plan.Error;
    Exit;
  end;
  for I := 0 to Plan.Count - 1 do
  begin
    Rc := VPAGraph_LoadPlanEntry(Plan, I, Plugin, One);
    if Rc = VPAGL_OK then
    begin
      Chosen := I;
      Result := VPAGL_OK;
      Exit;
    end;
    AppendLine(Detail, One);
  end;
  if Plan.Forced then
    AppendLine(Detail, 'backend ' + Plan.Backend[0] + ' was forced by ' +
      VPAGD_ENV_BACKEND + ', so no other backend was tried');
  Result := VPAGD_ERR_ALL_FAILED;
end;

end.
