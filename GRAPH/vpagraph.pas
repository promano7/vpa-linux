{ ===========================================================================
  vpagraph.pas - La API Graph de VPA sobre la tabla de funciones del plugin
  de backend. Fase 6 de WAYLAND.md (T6.1 y T6.3).

  Esta unidad es lo que las unidades de VPA ponen en su clausula uses en
  lugar de ptcgraph. Expone procedimientos con LOS MISMOS NOMBRES Y LAS
  MISMAS FIRMAS que ptcgraph (decision D-03): mismos tipos (smallint,
  ColorType = word, shortstring), mismas constantes con los mismos valores.
  Asi la migracion de una unidad es cambiar una palabra en su uses y no
  tocar ninguna de sus llamadas.

  Lo que hay aqui y lo que no:

    - SOLO lo que VPA enlaza hoy (tablas 1 y 2 de
      docs/vpagraph-api-inventory.md). Nada de Arc, FillPoly, TextWidth...
      (D-05, D-07, D-11): el dia que hagan falta se anaden aqui y al final
      de la ABI.
    - En ptcgraph, OutTextXY, Line, PutPixel, GetImage... son VARIABLES de
      tipo procedimiento que rellena el driver. Aqui son procedimientos
      normales: VPA nunca les asigna nada ni toma su direccion.

  Modo: la unidad se compila en OBJFPC porque usa el cargador y el detector
  (que trabajan con AnsiString: directiva $H+). Por eso en la interfaz las
  cadenas se declaran ShortString de forma EXPLICITA: con $H+, 'string'
  seria AnsiString y dejaria de coincidir con lo que pasa el codigo -Mtp.
  Los tipos de la ABI se toman de vpagraph_loader y NO de un segundo
  $I vpagraph_abi.inc: dos inclusiones son dos tipos distintos.

  Ciclo de vida (T6.3):

    InitGraph   lee la sesion, hace el plan (vpagraph_detect), y recorre el
                plan: cargar plugin -> resolver escala -> Init. Si cualquiera
                de los pasos falla y la seleccion es 'auto', descarga y
                prueba el siguiente backend del plan (T4.2: Init tambien
                cuenta como "falla"). Si es forzada no hay respaldo. Los
                motivos de TODOS los descartes se acumulan en
                VPAGraphInitDetail, uno por linea.
    CloseGraph  Shutdown del plugin y descarga del .so. Idempotente.

  Con el backend sin cargar (antes de InitGraph, despues de CloseGraph o si
  InitGraph fallo) todas las primitivas son inocuas: no dibujan, y las
  funciones devuelven 0. ptcgraph en la misma situacion revienta; aqui no,
  porque VPAEXIT puede llegar a pintar en una salida de emergencia.
  =========================================================================== }
unit vpagraph;

{$MODE OBJFPC}{$H+}

interface

{ vpagraph_loader va en la interfaz solo por PVPAGraphInterface
  (VPAGraphActiveInterface). Las clausulas uses no son transitivas: las
  unidades -Mtp que usan vpagraph no ven nada del cargador. }
uses
  vpagraph_loader;

{ ---------------------------------------------------------------------------
  Constantes y tipos reexportados (tabla 2 del inventario), con los mismos
  valores que ptcgraph: los de color viajan por SetColor y por los buferes
  de imagen; los de estilo y modo, por la ABI tal cual.
  --------------------------------------------------------------------------- }
type
  ColorType = word;

  ViewPortType = record
    x1, y1, x2, y2 : smallint;
    Clip : boolean;
  end;

const
  { colores }
  Black        = 0;   Blue         = 1;   Green        = 2;   Cyan       = 3;
  Red          = 4;   Magenta      = 5;   Brown        = 6;   LightGray  = 7;
  DarkGray     = 8;   LightBlue    = 9;   LightGreen   = 10;  LightCyan  = 11;
  LightRed     = 12;  LightMagenta = 13;  Yellow       = 14;  White      = 15;

  { estilo y grosor de linea }
  SolidLn   = 0;
  DottedLn  = 1;
  CenterLn  = 2;
  DashedLn  = 3;
  UserBitLn = 4;
  NormWidth  = 1;
  ThickWidth = 3;

  { modos de escritura }
  NormalPut = 0;
  XORPut    = 1;
  OrPut     = 2;

  { recorte del viewport }
  ClipOn  = true;
  ClipOff = false;

  { texto }
  LeftText   = 0;
  CenterText = 1;
  RightText  = 2;
  BottomText = 0;
  TopText    = 2;
  HorizDir   = 0;
  DefaultFont = 0;
  SmallFont   = 2;

  { relleno }
  SolidFill = 1;

  { driver, modo y resultado: solo existen para la llamada unica a
    InitGraph de VPAINIT y su comprobacion posterior. }
  D8bit       = 15;
  detectMode  = 30000;
  m640x480    = detectMode + 9;
  grOk          =   0;
  grNoInitGraph =  -1;
  grNotDetected =  -2;
  grInvalidMode = -10;
  grError       = -11;

{ ---------------------------------------------------------------------------
  Anadidos de VPAGraph (no existen en ptcgraph).
  --------------------------------------------------------------------------- }
var
  { Explicacion del ultimo InitGraph fallido: un motivo por backend probado,
    uno por linea, en ingles (D-13). Vacia si InitGraph fue bien. Es lo que
    VPAINIT ensena junto a 'Graphics initialization failure'. Con InitGraph
    correcto y seleccion 'auto' puede no estar vacia: guarda por que se
    descarto el backend preferido antes de quedarse con el de respaldo. }
  VPAGraphInitDetail : AnsiString = '';

{ Nombre del backend en uso ('x11', 'wayland') o '' si no hay ninguno. }
function VPAGraphBackendName: AnsiString;

{ Escala de ventana que se paso al backend en Init, en porcentaje. }
function VPAGraphScalePercent: longint;

{ La tabla de funciones del backend EN USO, o nil si no hay ninguno o si la
  ventana esta suspendida (entre RestoreCrtMode y SetGraphMode). Es el unico
  acceso a la tabla fuera de esta unidad y existe para
  GRAPH/vpagraph_input.pas (D-10): teclado y raton comparten plugin con el
  dibujo, pero no son API Graph y no tienen por que estar aqui. El puntero
  no se guarda entre llamadas: CloseGraph lo deja colgando. }
function VPAGraphActiveInterface: PVPAGraphInterface;

{ Volcado del framebuffer para la comparacion de escenas (T0.4, Fase 11).
  Mismos nombres y firmas que los anadidos de VENDOR/ptcgraph.pp, que es lo
  que llama UNIT/KEYBOARD.PAS con Ctrl-F12. VPADumpEnabled es True si
  VPA_GRAPH_DUMP trae un prefijo; VPADumpFrame escribe <prefijo>NNNN.ppm y
  .pal y devuelve el numero de fotograma (>0) o un negativo si falla. La
  numeracion la lleva el backend. }
function VPADumpEnabled: Boolean;
function VPADumpFrame: LongInt;

{ ---------------------------------------------------------------------------
  API Graph. Firmas de VENDOR/graphh.inc.
  --------------------------------------------------------------------------- }
procedure InitGraph(var GraphDriver: smallint; var GraphMode: smallint;
  const PathToDriver: ShortString);
procedure CloseGraph;
function  GraphResult: smallint;

{ El patron "suspender y reanudar la ventana" (inventario, 1.1; D-08). VPA
  solo usa estas tres juntas, para ejecutar un programa externo y volver:
      RestoreCrtMode; ...Exec...; SetGraphMode(GetGraphMode);
  RestoreCrtMode es Suspend de la ABI (cierra la ventana y devuelve la
  terminal) y el SetGraphMode que le sigue es Resume (reabre la ventana y
  rehace foco, escala y pantalla completa, y deja el estado de dibujo en
  sus valores por defecto, como hacia ptcgraph). Un SetGraphMode SIN
  RestoreCrtMode previo no hace nada: no hay modos entre los que cambiar, y
  los dos sitios que lo llaman asi (TCOMBAT, SCRSAVER) lo hacen tras
  BadVideoOrMouse, que en Linux nunca se cumple. }
procedure RestoreCrtMode;
procedure SetGraphMode(Mode: smallint);
function  GetGraphMode: smallint;

procedure ClearDevice;
procedure SetViewPort(X1, Y1, X2, Y2: smallint; Clip: Boolean);
procedure GetViewSettings(var viewport: ViewPortType);

procedure SetColor(Color: ColorType);
function  GetColor: ColorType;
procedure SetLineStyle(LineStyle: word; Pattern: word; Thickness: word);
procedure SetFillStyle(Pattern: word; Color: ColorType);
procedure SetWriteMode(WriteMode: smallint);

procedure PutPixel(X, Y: smallint; Color: ColorType);
function  GetPixel(X, Y: smallint): ColorType;
procedure Line(X1, Y1, X2, Y2: smallint);
procedure LineTo(X, Y: smallint);
procedure LineRel(Dx, Dy: smallint);
procedure MoveTo(X, Y: smallint);
procedure Rectangle(x1, y1, x2, y2: smallint);
procedure Bar(x1, y1, x2, y2: smallint);
procedure Circle(X, Y: smallint; Radius: Word);
procedure Ellipse(X, Y: smallint; stAngle, EndAngle: word;
  XRadius, YRadius: word);

function  ImageSize(X1, Y1, X2, Y2: smallint): longint;
procedure GetImage(X1, Y1, X2, Y2: smallint; var Bitmap);
procedure PutImage(X, Y: smallint; var Bitmap; BitBlt: Word);

procedure SetRGBPalette(ColorNum, RedValue, GreenValue, BlueValue: smallint);
procedure GetRGBPalette(ColorNum: smallint;
  var RedValue, GreenValue, BlueValue: smallint);

procedure OutTextXY(x, y: smallint; const TextString: ShortString);
procedure SetTextStyle(font, direction: word; charsize: word);
procedure SetTextJustify(horiz, vert: word);
function  InstallUserFont(const FontFileName: ShortString): smallint;

implementation

uses
  SysUtils, vpagraph_detect, vpagraph_errors;

var
  GPlugin : TVPAGraphPlugin;      { Loaded = False mientras no haya backend }
  GActive : Boolean = False;      { True entre un Init correcto y Shutdown }
  GResult : smallint = grNoInitGraph;
  GScale  : longint = 0;
  GSuspended : Boolean = False;   { entre RestoreCrtMode y SetGraphMode }

{ ---------------------------------------------------------------------------
  Escala de ventana. Es la logica de xfocus.ResolveScale trasladada al
  nucleo: la unica diferencia es que el tamano de la pantalla ya no se
  pregunta a Xlib sino al backend (GetScreenSize se puede llamar antes de
  Init). VPA_SCALE, en PORCENTAJE resultante (100 = 1x, 220 = 2.2x):
    sin definir      -> 200
    1                -> 100 (640x480 nativo)
    fullscreen|full|max -> el mayor 4:3 que cabe, y ademas pantalla completa
    N de 2 a 20      -> N*100 (compatibilidad: "N veces")
    N de 21 a 800    -> N por ciento
  Siempre recortado a lo que cabe en la pantalla. Si el backend no sabe el
  tamano de la pantalla no se recorta por arriba mas que a MaxPct.
  --------------------------------------------------------------------------- }
const
  ScaleMinPct    = 100;
  ScaleMaxPct    = 800;
  ScaleLegacyMax = 20;
  ScaleDefault   = 200;

function ResolveScale(ScreenW, ScreenH: longint;
  out WantFullscreen: Boolean): longint;
var
  v: AnsiString;
  n, code, maxfit: longint;
begin
  WantFullscreen := False;
  maxfit := ScaleMaxPct;
  if (ScreenW > 0) and (ScreenH > 0) then
  begin
    maxfit := Trunc(100.0 * ScreenW / 640);
    if Trunc(100.0 * ScreenH / 480) < maxfit then
      maxfit := Trunc(100.0 * ScreenH / 480);
  end;
  if maxfit < ScaleMinPct then maxfit := ScaleMinPct;
  if maxfit > ScaleMaxPct then maxfit := ScaleMaxPct;

  v := LowerCase(Trim(GetEnvironmentVariable('VPA_SCALE')));
  if v = '' then
    n := ScaleDefault
  else if (v = 'fullscreen') or (v = 'full') or (v = 'max') then
  begin
    n := maxfit;
    WantFullscreen := True;
  end
  else
  begin
    Val(v, n, code);
    if (code <> 0) or (n < 1) then
      n := 100                       { no es un numero: sin escalar }
    else if n <= ScaleLegacyMax then
      n := n * 100;
  end;
  if n > maxfit then n := maxfit;
  if n < ScaleMinPct then n := ScaleMinPct;
  Result := n;
end;

{ ---------------------------------------------------------------------------
  Ciclo de vida
  --------------------------------------------------------------------------- }
procedure AddDetail(const S: AnsiString);
begin
  if S = '' then Exit;
  if VPAGraphInitDetail <> '' then
    VPAGraphInitDetail := VPAGraphInitDetail + LineEnding;
  VPAGraphInitDetail := VPAGraphInitDetail + S;
end;

{ Arranca el backend ya cargado en GPlugin. True si Init fue bien; si no,
  anota el motivo y deja GPlugin descargado. }
function StartLoadedBackend(const Backend: AnsiString): Boolean;
var
  Params : TVPAGraphInitParams;
  Title  : AnsiString;
  SW, SH : TVPAGraphInt32;
  Full   : Boolean;
  R      : TVPAGraphInt32;
begin
  SW := 0; SH := 0;
  if GPlugin.Iface.GetScreenSize(@SW, @SH) <> VPAG_OK then
  begin
    SW := 0; SH := 0;
  end;
  GScale := ResolveScale(SW, SH, Full);

  Title := ParamStr(0);
  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize   := SizeOf(Params);
  Params.Width        := 640;
  Params.Height       := 480;
  Params.ScalePercent := GScale;
  if Full then Params.Fullscreen := VPAG_TRUE;
  Params.WindowTitle  := PAnsiChar(Title);

  VPAGraph_Log('init ' + Backend + ': 640x480, scale ' + IntToStr(GScale) +
    '%, fullscreen ' + IntToStr(Ord(Full)));
  R := GPlugin.Iface.Init(@Params);
  Result := R = VPAG_OK;
  if not Result then
  begin
    AddDetail(Backend + ': ' + VPAGraph_FormatError(R,
      VPAGraph_PluginMessage(GPlugin), vglEnglish));
    VPAGraph_UnloadPlugin(GPlugin);
  end;
end;

procedure InitGraph(var GraphDriver: smallint; var GraphMode: smallint;
  const PathToDriver: ShortString);
var
  Session : TVPAGraphSession;
  Plan    : TVPAGraphPlan;
  Detail  : AnsiString;
  I       : Integer;
begin
  if GActive then CloseGraph;
  VPAGraphInitDetail := '';
  GResult := grError;

  { VPA pide siempre lo mismo; cualquier otra cosa es un error de quien llama
    y no algo que un backend tenga que interpretar. }
  if (GraphDriver <> D8bit) or (GraphMode <> m640x480) then
  begin
    GResult := grInvalidMode;
    AddDetail('InitGraph: only D8bit / m640x480 is supported');
    Exit;
  end;

  VPAGraph_ReadSession(Session);
  if VPAGraph_PlanBackends(VPAGraph_NormalizeRequest(Session.Requested),
       Session, Plan) <> VPAGL_OK then
  begin
    GResult := grNotDetected;
    AddDetail(Plan.Detail);
    Exit;
  end;

  for I := 0 to Plan.Count - 1 do
  begin
    Detail := '';
    if VPAGraph_LoadPlanEntry(Plan, I, GPlugin, Detail) <> VPAGL_OK then
    begin
      AddDetail(Detail);
      Continue;
    end;
    if StartLoadedBackend(Plan.Backend[I]) then
    begin
      GActive := True;
      GResult := grOk;
      VPAGraph_Log('backend in use: ' + Plan.Backend[I]);
      Exit;
    end;
  end;
  GResult := grNotDetected;
end;

procedure CloseGraph;
begin
  if GActive then
  begin
    GActive := False;
    GSuspended := False;
    GPlugin.Iface.Shutdown();
  end;
  VPAGraph_UnloadPlugin(GPlugin);   { idempotente }
  GResult := grNoInitGraph;
end;

{ Como en BGI, leer el resultado lo consume. VPA solo lo mira una vez, tras
  InitGraph. El GraphResult de la ABI no se consulta: las primitivas de
  dibujo de VPA no comprueban errores y no hay nada que hacer con el. }
function GraphResult: smallint;
begin
  Result := GResult;
  GResult := grOk;
end;

procedure RestoreCrtMode;
begin
  if GActive and not GSuspended then
    if GPlugin.Iface.Suspend() = VPAG_OK then
      GSuspended := True;
end;

procedure SetGraphMode(Mode: smallint);
begin
  if GActive and GSuspended then
  begin
    GSuspended := False;
    if GPlugin.Iface.Resume() <> VPAG_OK then
      GResult := grError;
  end;
end;

function GetGraphMode: smallint;
begin
  Result := m640x480;
end;

function VPAGraphBackendName: AnsiString;
begin
  if GActive then
    Result := AnsiString(GPlugin.Iface.BackendName)
  else
    Result := '';
end;

function VPAGraphScalePercent: longint;
begin
  Result := GScale;
end;

{ El tipo se cualifica: vpagraph_errors tambien incluye vpagraph_abi.inc, va
  detras en el uses de la implementacion y su PVPAGraphInterface -otro tipo
  para FPC- taparia al de la interfaz. }
function VPAGraphActiveInterface: vpagraph_loader.PVPAGraphInterface;
begin
  if GActive and not GSuspended then
    Result := @GPlugin.Iface
  else
    Result := nil;
end;

var
  GDumpPrefix  : AnsiString = '';
  GDumpChecked : Boolean = False;

function VPADumpEnabled: Boolean;
begin
  if not GDumpChecked then
  begin
    GDumpPrefix := GetEnvironmentVariable('VPA_GRAPH_DUMP');
    GDumpChecked := True;
  end;
  Result := GDumpPrefix <> '';
end;

function VPADumpFrame: LongInt;
begin
  Result := -1;
  if GActive and VPADumpEnabled then
    Result := GPlugin.Iface.DumpFrame(PAnsiChar(GDumpPrefix));
end;

{ ---------------------------------------------------------------------------
  Primitivas: una linea cada una. Los smallint se extienden a 32 bits con
  signo y los word sin el, que es lo que declara la ABI.
  --------------------------------------------------------------------------- }
procedure ClearDevice;
begin
  if GActive then GPlugin.Iface.ClearDevice();
end;

procedure SetViewPort(X1, Y1, X2, Y2: smallint; Clip: Boolean);
begin
  if GActive then GPlugin.Iface.SetViewPort(X1, Y1, X2, Y2, Ord(Clip));
end;

procedure GetViewSettings(var viewport: ViewPortType);
var
  A, B, C, D : TVPAGraphInt32;
  Cl : TVPAGraphUInt8;
begin
  A := 0; B := 0; C := 0; D := 0; Cl := 0;
  if GActive then GPlugin.Iface.GetViewSettings(@A, @B, @C, @D, @Cl);
  viewport.x1 := A; viewport.y1 := B;
  viewport.x2 := C; viewport.y2 := D;
  viewport.Clip := Cl <> 0;
end;

procedure SetColor(Color: ColorType);
begin
  if GActive then GPlugin.Iface.SetColor(Color);
end;

function GetColor: ColorType;
begin
  if GActive then Result := GPlugin.Iface.GetColor() else Result := 0;
end;

procedure SetLineStyle(LineStyle: word; Pattern: word; Thickness: word);
begin
  if GActive then GPlugin.Iface.SetLineStyle(LineStyle, Pattern, Thickness);
end;

procedure SetFillStyle(Pattern: word; Color: ColorType);
begin
  if GActive then GPlugin.Iface.SetFillStyle(Pattern, Color);
end;

{ WriteMode llega como smallint; un negativo no es ningun modo valido y el
  backend lo trata como lo trataria ptcgraph (cae en NormalPut). }
procedure SetWriteMode(WriteMode: smallint);
begin
  if GActive then GPlugin.Iface.SetWriteMode(TVPAGraphUInt32(longint(WriteMode)));
end;

procedure PutPixel(X, Y: smallint; Color: ColorType);
begin
  if GActive then GPlugin.Iface.PutPixel(X, Y, Color);
end;

function GetPixel(X, Y: smallint): ColorType;
begin
  if GActive then Result := GPlugin.Iface.GetPixel(X, Y) else Result := 0;
end;

procedure Line(X1, Y1, X2, Y2: smallint);
begin
  if GActive then GPlugin.Iface.Line(X1, Y1, X2, Y2);
end;

procedure LineTo(X, Y: smallint);
begin
  if GActive then GPlugin.Iface.LineTo(X, Y);
end;

procedure LineRel(Dx, Dy: smallint);
begin
  if GActive then GPlugin.Iface.LineRel(Dx, Dy);
end;

procedure MoveTo(X, Y: smallint);
begin
  if GActive then GPlugin.Iface.MoveTo(X, Y);
end;

procedure Rectangle(x1, y1, x2, y2: smallint);
begin
  if GActive then GPlugin.Iface.Rectangle(x1, y1, x2, y2);
end;

procedure Bar(x1, y1, x2, y2: smallint);
begin
  if GActive then GPlugin.Iface.Bar(x1, y1, x2, y2);
end;

procedure Circle(X, Y: smallint; Radius: Word);
begin
  if GActive then GPlugin.Iface.Circle(X, Y, Radius);
end;

procedure Ellipse(X, Y: smallint; stAngle, EndAngle: word;
  XRadius, YRadius: word);
begin
  if GActive then
    GPlugin.Iface.Ellipse(X, Y, stAngle, EndAngle, XRadius, YRadius);
end;

{ --- Imagenes. El formato del bufer es el de la seccion 7 del inventario y
  lo reserva VPA. La API Graph no dice cuanto mide el bufer y la ABI lo
  pide: en GetImage se pasa lo que ImageSize dice que hace falta para esa
  region (que es lo que VPA ha reservado, porque lo calculo con la misma
  funcion), y en PutImage lo que declara la cabecera del propio bufer. --- }
function ImageSize(X1, Y1, X2, Y2: smallint): longint;
begin
  if GActive then
    Result := GPlugin.Iface.ImageSize(X1, Y1, X2, Y2)
  else
    Result := 0;
end;

procedure GetImage(X1, Y1, X2, Y2: smallint; var Bitmap);
begin
  if GActive then
    GPlugin.Iface.GetImage(X1, Y1, X2, Y2, @Bitmap,
      GPlugin.Iface.ImageSize(X1, Y1, X2, Y2));
end;

procedure PutImage(X, Y: smallint; var Bitmap; BitBlt: Word);
var
  W, H : longint;
begin
  if not GActive then Exit;
  W := PLongint(@Bitmap)[0];
  H := PLongint(@Bitmap)[1];
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then Exit;
  GPlugin.Iface.PutImage(X, Y, @Bitmap, 12 + W * H * 2, BitBlt);
end;

procedure SetRGBPalette(ColorNum, RedValue, GreenValue, BlueValue: smallint);
begin
  if GActive then
    GPlugin.Iface.SetRGBPalette(ColorNum, RedValue, GreenValue, BlueValue);
end;

procedure GetRGBPalette(ColorNum: smallint;
  var RedValue, GreenValue, BlueValue: smallint);
var
  R, G, B : TVPAGraphInt32;
begin
  R := 0; G := 0; B := 0;
  if GActive then GPlugin.Iface.GetRGBPalette(ColorNum, @R, @G, @B);
  RedValue := R; GreenValue := G; BlueValue := B;
end;

{ --- Texto. Ningun String cruza la frontera (regla 3 de la ABI): el
  shortstring se copia a un bufer local terminado en cero. 256 bytes en la
  pila, sin tocar el heap: OutTextXY es la llamada mas frecuente de VPA. --- }
procedure OutTextXY(x, y: smallint; const TextString: ShortString);
var
  Buf : array[0..255] of AnsiChar;
  L   : Integer;
begin
  if not GActive then Exit;
  L := Length(TextString);
  if L > 0 then Move(TextString[1], Buf[0], L);
  Buf[L] := #0;
  GPlugin.Iface.OutTextXY(x, y, @Buf[0]);
end;

procedure SetTextStyle(font, direction: word; charsize: word);
begin
  if GActive then GPlugin.Iface.SetTextStyle(font, direction, charsize);
end;

procedure SetTextJustify(horiz, vert: word);
begin
  if GActive then GPlugin.Iface.SetTextJustify(horiz, vert);
end;

function InstallUserFont(const FontFileName: ShortString): smallint;
var
  Buf : array[0..255] of AnsiChar;
  L   : Integer;
begin
  Result := grError;
  if not GActive then Exit;
  L := Length(FontFileName);
  if L > 0 then Move(FontFileName[1], Buf[0], L);
  Buf[L] := #0;
  Result := GPlugin.Iface.InstallUserFont(@Buf[0]);
end;

finalization
  { Un Halt sin CloseGraph (salidas de emergencia) no debe dejar vivo el
    hilo del backend ni el .so cargado. }
  CloseGraph;
end.
