{ vpagraph_x11_impl - adaptadores cdecl de la ABI v1 sobre ptcgraph.
  Fase 5 de WAYLAND.md, tareas T5.4 (adaptadores) y T5.5 (ciclo de vida).

  Cada adaptador:
    - recibe los tipos de tamano fijo de la ABI y llama a ptcgraph con los
      suyos (smallint, word, ColorType, shortstring);
    - lleva su propio try..except: ninguna excepcion cruza la frontera
      (regla 5 de la ABI). Lo que se captura se guarda con SetError y se
      puede consultar con GetLastError/GraphResult;
    - no reserva nada que tenga que liberar el llamante, ni al reves.

  La traduccion PAnsiChar -> shortstring de OutTextXY e InstallUserFont
  ocurre aqui; la contraria (shortstring -> PAnsiChar) la hace el nucleo,
  GRAPH/vpagraph.pas, en la Fase 6.

  Lo que NO esta en esta unidad: el bloque de ventana/foco/escala (T5.6,
  T5.7: vpagraph_x11_window.pas) y el de teclado y raton (T5.8:
  vpagraph_x11_input.pas). Esta unidad los engancha en el ciclo de vida y
  los publica en VPAGraph_GetInterface. Hasta que exista el de entrada,
  esas casillas quedan a nil y el cargador del nucleo rechaza el plugin, que
  es lo correcto: un plugin sin entrada no es jugable. }
unit vpagraph_x11_impl;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils;

{$I vpagraph_abi.inc}

{ Punto de entrada del plugin (T2.13). Lo exporta vpagraph_x11.lpr. }
function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
  InterfaceSize: TVPAGraphUInt32;
  InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;

{ Ultimo error del plugin, para las otras unidades vpagraph_x11_*. }
procedure SetError(Code: TVPAGraphInt32; const Msg: AnsiString);

{ Guarda una excepcion capturada como error interno. Se llama SOLO desde un
  bloque except: E.Message vive en el RTL de este .so y no sale de aqui. }
procedure InternalError(const Where: AnsiString; E: Exception);

{ True entre un Init correcto y el Shutdown siguiente. }
function Initialized: Boolean;

implementation

uses
  ptc, ptcgraph, vpagraph_x11_window;

const
  BackendNameStr    : PAnsiChar = 'x11';
  { Decision D-19: el motor y con que se compilo, compuesto en tiempo de
    compilacion para que no se desactualice solo. Se copia a un buffer
    estatico en la inicializacion: una constante PAnsiChar formada por
    concatenacion NO es un literal y FPC la deja apuntando a un temporal. }
  BackendVersionText = '1.0 (ptcgraph, ' + PTCPAS_VERSION +
                       ', FPC ' + {$I %FPCVERSION%} + ')';

  { Unico modo que VPA usa. Otro tamano de superficie es VPAG_ERR_UNSUPPORTED:
    ptcgraph sabria abrirlo, pero las fuentes, las imagenes doradas y el
    raton estan calibrados para 640x480 y nadie ha pedido otra cosa. }
  SurfaceWidth  = 640;
  SurfaceHeight = 480;

var
  BackendVersionBuf : array[0..127] of AnsiChar;
  GInitialized : Boolean = False;
  LastError    : TVPAGraphInt32 = VPAG_OK;
  LastMessage  : array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;

{ ---------------------------------------------------------------------------
  Errores
  --------------------------------------------------------------------------- }

procedure SetError(Code: TVPAGraphInt32; const Msg: AnsiString);
var
  N: Integer;
begin
  LastError := Code;
  N := Length(Msg);
  if N > High(LastMessage) then N := High(LastMessage);
  if N > 0 then Move(Msg[1], LastMessage[0], N);
  LastMessage[N] := #0;
end;

function Initialized: Boolean;
begin
  Initialized := GInitialized;
end;

procedure InternalError(const Where: AnsiString; E: Exception);
begin
  SetError(VPAG_ERR_INTERNAL, Where + ': ' + E.ClassName + ': ' + E.Message);
end;

{ Copia de PAnsiChar a shortstring, recortando a 255 y tolerando nil. }
function PCharToShort(P: PAnsiChar): ShortString;
var
  N: Integer;
begin
  Result := '';
  if P = nil then Exit;
  N := 0;
  while (P[N] <> #0) and (N < 255) do Inc(N);
  SetLength(Result, N);
  if N > 0 then Move(P^, Result[1], N);
end;

{ ---------------------------------------------------------------------------
  T2.5 - Ciclo de vida
  --------------------------------------------------------------------------- }

function X11Init(Params: PVPAGraphInitParams): TVPAGraphInt32; cdecl;
var
  GD, GM: smallint;
  R: smallint;
begin
  try
    if Params = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'Init: Params is nil');
      Exit(VPAG_ERR_INVALID_PARAM);
    end;
    if Params^.StructSize < SizeOf(TVPAGraphInitParams) then
    begin
      SetError(VPAG_ERR_STRUCT_SIZE, 'Init: TVPAGraphInitParams too small');
      Exit(VPAG_ERR_STRUCT_SIZE);
    end;
    if GInitialized then
    begin
      SetError(VPAG_ERR_INIT, 'Init: already initialized (call Shutdown first)');
      Exit(VPAG_ERR_INIT);
    end;
    if (Params^.Width <> SurfaceWidth) or (Params^.Height <> SurfaceHeight) then
    begin
      SetError(VPAG_ERR_UNSUPPORTED, 'Init: this backend only supports a ' +
        IntToStr(SurfaceWidth) + 'x' + IntToStr(SurfaceHeight) + ' surface');
      Exit(VPAG_ERR_UNSUPPORTED);
    end;

    { El titulo: ptcgraph usa ParamStr(0) si nadie lo cambia. VPA pasa hoy
      exactamente eso, asi que un titulo nil lo deja como esta. }
    if Params^.WindowTitle <> nil then
      WindowTitle := AnsiString(Params^.WindowTitle);

    { La escala ya viene resuelta por el nucleo (porcentaje). 0 deja a
      ptcgraph leer VPA_SCALE del entorno, como hace sin VPA-Linux por medio;
      el nucleo nunca pasa 0, pero el arnes de pruebas si puede. }
    VPAForceScale := Params^.ScalePercent;

    GD := D8bit;
    GM := m640x480;
    InitGraph(GD, GM, '');
    R := ptcgraph.GraphResult;
    if R <> grOk then
    begin
      { T5.5b: sin servidor X, ptcgraph devuelve grError y deja el motivo
        de ptc ('Cannot open X display') en VPALastOpenError. ptc encadena
        los errores anidados con #10: aqui se deja en una sola linea. }
      if VPALastOpenError <> '' then
        SetError(VPAG_ERR_VIDEO, 'InitGraph failed: ' +
          StringReplace(TrimRight(VPALastOpenError), #10, '; ', [rfReplaceAll]))
      else
        SetError(VPAG_ERR_VIDEO, 'InitGraph failed: ' + GraphErrorMsg(R));
      Exit(VPAG_ERR_VIDEO);
    end;

    { T5.6/T5.7: conexion X propia del plugin, foco de teclado y, si se
      pidio, pantalla completa. Es la terna GrabInputFocus +
      ApplyWindowScale + RequestFullscreen que VPA hacia tras InitGraph. }
    if not WindowConnect then
    begin
      CloseGraph;
      SetError(VPAG_ERR_VIDEO, 'Init: cannot open a second X connection');
      Exit(VPAG_ERR_VIDEO);
    end;
    GInitialized := True;
    if Params^.Fullscreen <> VPAG_FALSE then
      X11SetFullscreen(VPAG_TRUE);   { solo anota: la ventana la toma Attach }
    WindowAttach;

    SetError(VPAG_OK, '');
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('Init', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

function X11Shutdown: TVPAGraphInt32; cdecl;
begin
  try
    if GInitialized then
    begin
      GInitialized := False;   { antes de cerrar: idempotente aunque falle }
      WindowDetach;
      CloseGraph;
      WindowDisconnect;
    end;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('Shutdown', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

function X11GetLastError(Buffer: PAnsiChar; BufferSize: TVPAGraphUInt32): TVPAGraphInt32; cdecl;
var
  N, Len: TVPAGraphUInt32;
begin
  Len := 0;
  while LastMessage[Len] <> #0 do Inc(Len);
  if (Buffer <> nil) and (BufferSize > 0) then
  begin
    N := Len;
    if N > BufferSize - 1 then N := BufferSize - 1;
    if N > 0 then Move(LastMessage[0], Buffer^, N);
    Buffer[N] := #0;
  end;
  Result := TVPAGraphInt32(Len);
end;

{ ptcgraph pinta directamente: su hilo copia la superficie a la ventana a su
  ritmo. No hay fotograma que entregar. }
function X11Present: TVPAGraphInt32; cdecl;
begin
  if not GInitialized then
  begin
    SetError(VPAG_ERR_INIT, 'Present before Init');
    Exit(VPAG_ERR_INIT);
  end;
  Result := VPAG_OK;
end;

{ El ultimo error de la ABI, sin consumirlo (a diferencia del GraphResult de
  BGI). Init ya ha traducido el GraphResult de ptcgraph a VPAG_ERR_VIDEO. }
function X11GraphResult: TVPAGraphInt32; cdecl;
begin
  Result := LastError;
end;

{ Suspend/Resume (decision D-08): la pareja RestoreCrtMode +
  SetGraphMode(GetGraphMode) que VPA usa en ocho sitios (inventario, 1.1)
  para ejecutar algo externo y volver. RestoreCrtMode cierra la ventana de
  ptc y SetGraphMode(GetGraphMode) la vuelve a abrir; el contenido se pierde
  y VPA redibuja. Resume rehace ademas el foco y la pantalla completa
  (WindowAttach, T5.7), que hoy hace la terna de xfocus que siempre sigue a
  esta pareja; la escala no hay que rehacerla, VPAForceScale sigue puesto y
  ptc vuelve a abrir la consola con ella. }
function X11Suspend: TVPAGraphInt32; cdecl;
begin
  try
    if not GInitialized then
    begin
      SetError(VPAG_ERR_INIT, 'Suspend before Init');
      Exit(VPAG_ERR_INIT);
    end;
    WindowDetach;
    RestoreCrtMode;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('Suspend', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

function X11Resume: TVPAGraphInt32; cdecl;
begin
  try
    if not GInitialized then
    begin
      SetError(VPAG_ERR_INIT, 'Resume before Init');
      Exit(VPAG_ERR_INIT);
    end;
    SetGraphMode(GetGraphMode);
    if ptcgraph.GraphResult <> grOk then
    begin
      SetError(VPAG_ERR_VIDEO, 'Resume: SetGraphMode failed: ' +
        GraphErrorMsg(ptcgraph.GraphResult));
      Exit(VPAG_ERR_VIDEO);
    end;
    WindowAttach;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('Resume', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  T2.6 - Dibujo
  Las coordenadas de 32 bits se recortan a smallint al pasar a ptcgraph, que
  es lo mismo que hace hoy el codigo de VPA al llamarlo con sus enteros de
  16 bits. Un valor fuera de rango se trunca (sin excepcion: la conversion
  es explicita y las comprobaciones de rango no la vigilan).
  --------------------------------------------------------------------------- }

procedure X11ClearDevice; cdecl;
begin
  try
    ClearDevice;
  except
    on E: Exception do InternalError('ClearDevice', E);
  end;
end;

procedure X11SetViewPort(X1, Y1, X2, Y2: TVPAGraphInt32; Clip: TVPAGraphBool); cdecl;
begin
  try
    SetViewPort(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2), Clip <> VPAG_FALSE);
  except
    on E: Exception do InternalError('SetViewPort', E);
  end;
end;

procedure X11GetViewSettings(X1, Y1, X2, Y2: PVPAGraphInt32; Clip: PVPAGraphUInt8); cdecl;
var
  V: ViewPortType;
begin
  try
    GetViewSettings(V);
    if X1 <> nil then X1^ := V.x1;
    if Y1 <> nil then Y1^ := V.y1;
    if X2 <> nil then X2^ := V.x2;
    if Y2 <> nil then Y2^ := V.y2;
    if Clip <> nil then
      if V.Clip then Clip^ := VPAG_TRUE else Clip^ := VPAG_FALSE;
  except
    on E: Exception do InternalError('GetViewSettings', E);
  end;
end;

procedure X11SetColor(Color: TVPAGraphUInt32); cdecl;
begin
  try
    SetColor(ColorType(Color));
  except
    on E: Exception do InternalError('SetColor', E);
  end;
end;

function X11GetColor: TVPAGraphUInt32; cdecl;
begin
  Result := 0;
  try
    Result := TVPAGraphUInt32(GetColor);
  except
    on E: Exception do InternalError('GetColor', E);
  end;
end;

procedure X11SetLineStyle(LineStyle, Pattern, Thickness: TVPAGraphUInt32); cdecl;
begin
  try
    SetLineStyle(word(LineStyle), word(Pattern), word(Thickness));
  except
    on E: Exception do InternalError('SetLineStyle', E);
  end;
end;

procedure X11SetFillStyle(Pattern: TVPAGraphUInt32; Color: TVPAGraphUInt32); cdecl;
begin
  try
    SetFillStyle(word(Pattern), ColorType(Color));
  except
    on E: Exception do InternalError('SetFillStyle', E);
  end;
end;

procedure X11SetWriteMode(WriteMode: TVPAGraphUInt32); cdecl;
begin
  try
    SetWriteMode(smallint(WriteMode));
  except
    on E: Exception do InternalError('SetWriteMode', E);
  end;
end;

procedure X11PutPixel(X, Y: TVPAGraphInt32; Color: TVPAGraphUInt32); cdecl;
begin
  try
    PutPixel(smallint(X), smallint(Y), ColorType(Color));
  except
    on E: Exception do InternalError('PutPixel', E);
  end;
end;

function X11GetPixel(X, Y: TVPAGraphInt32): TVPAGraphUInt32; cdecl;
begin
  Result := 0;
  try
    Result := TVPAGraphUInt32(GetPixel(smallint(X), smallint(Y)));
  except
    on E: Exception do InternalError('GetPixel', E);
  end;
end;

procedure X11Line(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
  try
    Line(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2));
  except
    on E: Exception do InternalError('Line', E);
  end;
end;

procedure X11LineTo(X, Y: TVPAGraphInt32); cdecl;
begin
  try
    LineTo(smallint(X), smallint(Y));
  except
    on E: Exception do InternalError('LineTo', E);
  end;
end;

procedure X11LineRel(DX, DY: TVPAGraphInt32); cdecl;
begin
  try
    LineRel(smallint(DX), smallint(DY));
  except
    on E: Exception do InternalError('LineRel', E);
  end;
end;

procedure X11MoveTo(X, Y: TVPAGraphInt32); cdecl;
begin
  try
    MoveTo(smallint(X), smallint(Y));
  except
    on E: Exception do InternalError('MoveTo', E);
  end;
end;

procedure X11Rectangle(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
  try
    Rectangle(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2));
  except
    on E: Exception do InternalError('Rectangle', E);
  end;
end;

procedure X11Bar(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
  try
    Bar(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2));
  except
    on E: Exception do InternalError('Bar', E);
  end;
end;

procedure X11Circle(X, Y: TVPAGraphInt32; Radius: TVPAGraphUInt32); cdecl;
begin
  try
    Circle(smallint(X), smallint(Y), word(Radius));
  except
    on E: Exception do InternalError('Circle', E);
  end;
end;

procedure X11Ellipse(X, Y: TVPAGraphInt32; StartAngle, EndAngle: TVPAGraphInt32;
  XRadius, YRadius: TVPAGraphUInt32); cdecl;
begin
  try
    Ellipse(smallint(X), smallint(Y), word(StartAngle), word(EndAngle),
      word(XRadius), word(YRadius));
  except
    on E: Exception do InternalError('Ellipse', E);
  end;
end;

{ ---------------------------------------------------------------------------
  T2.7 - Imagenes
  El buffer es del llamante y su diseno es el de ptcgraph (cabecera de 12
  bytes + un word por pixel). BitmapSize es la unica defensa contra un
  tamano mal calculado al otro lado: si no cabe, no se toca el buffer.
  --------------------------------------------------------------------------- }

function X11ImageSize(X1, Y1, X2, Y2: TVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  Result := 0;
  try
    Result := ImageSize(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2));
  except
    on E: Exception do InternalError('ImageSize', E);
  end;
end;

procedure X11GetImage(X1, Y1, X2, Y2: TVPAGraphInt32; Bitmap: Pointer;
  BitmapSize: TVPAGraphInt32); cdecl;
var
  Needed: LongInt;
begin
  try
    if Bitmap = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'GetImage: Bitmap is nil');
      Exit;
    end;
    Needed := ImageSize(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2));
    if BitmapSize < Needed then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'GetImage: buffer of ' +
        IntToStr(BitmapSize) + ' bytes, ' + IntToStr(Needed) + ' needed');
      Exit;
    end;
    GetImage(smallint(X1), smallint(Y1), smallint(X2), smallint(Y2), Bitmap^);
  except
    on E: Exception do InternalError('GetImage', E);
  end;
end;

procedure X11PutImage(X, Y: TVPAGraphInt32; Bitmap: Pointer;
  BitmapSize: TVPAGraphInt32; BitBlt: TVPAGraphUInt32); cdecl;
var
  W, H: LongInt;
  Needed: LongInt;
begin
  try
    if Bitmap = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'PutImage: Bitmap is nil');
      Exit;
    end;
    { La cabecera dice cuanto ocupa la imagen; si el buffer declarado es
      mas corto, no se lee mas alla de el. }
    if BitmapSize < 12 then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'PutImage: buffer shorter than the header');
      Exit;
    end;
    W := PLongInt(Bitmap)^;
    H := PLongInt(PByte(Bitmap) + 4)^;
    Needed := 12 + W * H * 2;
    if (W < 0) or (H < 0) or (BitmapSize < Needed) then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'PutImage: buffer of ' +
        IntToStr(BitmapSize) + ' bytes, ' + IntToStr(Needed) + ' needed');
      Exit;
    end;
    PutImage(smallint(X), smallint(Y), Bitmap^, word(BitBlt));
  except
    on E: Exception do InternalError('PutImage', E);
  end;
end;

{ ---------------------------------------------------------------------------
  T2.8 - Paleta
  --------------------------------------------------------------------------- }

procedure X11SetRGBPalette(ColorNum, R, G, B: TVPAGraphInt32); cdecl;
begin
  try
    SetRGBPalette(smallint(ColorNum), smallint(R), smallint(G), smallint(B));
  except
    on E: Exception do InternalError('SetRGBPalette', E);
  end;
end;

procedure X11GetRGBPalette(ColorNum: TVPAGraphInt32; R, G, B: PVPAGraphInt32); cdecl;
var
  PR, PG, PB: smallint;
begin
  try
    GetRGBPalette(smallint(ColorNum), PR, PG, PB);
    if R <> nil then R^ := PR;
    if G <> nil then G^ := PG;
    if B <> nil then B^ := PB;
  except
    on E: Exception do InternalError('GetRGBPalette', E);
  end;
end;

procedure X11SetRGBPaletteBlock(FirstColor, Count: TVPAGraphInt32;
  RGBTriplets: PVPAGraphUInt8); cdecl;
var
  I: TVPAGraphInt32;
begin
  try
    if (RGBTriplets = nil) or (Count <= 0) then Exit;
    for I := 0 to Count - 1 do
      SetRGBPalette(smallint(FirstColor + I),
        RGBTriplets[I * 3], RGBTriplets[I * 3 + 1], RGBTriplets[I * 3 + 2]);
  except
    on E: Exception do InternalError('SetRGBPaletteBlock', E);
  end;
end;

{ ---------------------------------------------------------------------------
  T2.9 - Texto
  --------------------------------------------------------------------------- }

procedure X11OutTextXY(X, Y: TVPAGraphInt32; Text: PAnsiChar); cdecl;
begin
  try
    OutTextXY(smallint(X), smallint(Y), PCharToShort(Text));
  except
    on E: Exception do InternalError('OutTextXY', E);
  end;
end;

procedure X11SetTextStyle(Font, Direction, CharSize: TVPAGraphUInt32); cdecl;
begin
  try
    SetTextStyle(word(Font), word(Direction), word(CharSize));
  except
    on E: Exception do InternalError('SetTextStyle', E);
  end;
end;

procedure X11SetTextJustify(Horiz, Vert: TVPAGraphUInt32); cdecl;
begin
  try
    SetTextJustify(word(Horiz), word(Vert));
  except
    on E: Exception do InternalError('SetTextJustify', E);
  end;
end;

{ ptcgraph devuelve un identificador positivo, o un negativo si no pudo
  cargar el fichero; se pasa tal cual, que ya cumple la ABI. }
function X11InstallUserFont(FontFileName: PAnsiChar): TVPAGraphInt32; cdecl;
begin
  Result := VPAG_ERR_INVALID_PARAM;
  try
    if FontFileName = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'InstallUserFont: name is nil');
      Exit;
    end;
    Result := InstallUserFont(PCharToShort(FontFileName));
  except
    on E: Exception do
    begin
      InternalError('InstallUserFont', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  Diagnostico
  --------------------------------------------------------------------------- }

function X11DumpFrame(Prefix: PAnsiChar): TVPAGraphInt32; cdecl;
begin
  Result := VPAG_ERR_INVALID_PARAM;
  try
    if not GInitialized then
    begin
      SetError(VPAG_ERR_INIT, 'DumpFrame before Init');
      Exit(VPAG_ERR_INIT);
    end;
    if Prefix = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'DumpFrame: Prefix is nil');
      Exit;
    end;
    Result := VPADumpFrameTo(AnsiString(Prefix));
    if Result < 0 then
      SetError(VPAG_ERR_VIDEO, 'DumpFrame: VPADumpFrame returned ' + IntToStr(Result));
  except
    on E: Exception do
    begin
      InternalError('DumpFrame', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  T2.13 - Punto de entrada
  --------------------------------------------------------------------------- }

function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
  InterfaceSize: TVPAGraphUInt32;
  InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;
begin
  if InterfaceOut = nil then
    Exit(VPAG_ERR_INVALID_PARAM);
  if RequestedABIVersion <> VPAGRAPH_ABI_VERSION then
    Exit(VPAG_ERR_ABI_MISMATCH);
  if InterfaceSize < SizeOf(TVPAGraphInterface) then
    Exit(VPAG_ERR_STRUCT_SIZE);

  FillChar(InterfaceOut^, SizeOf(TVPAGraphInterface), 0);
  with InterfaceOut^ do
  begin
    StructSize         := SizeOf(TVPAGraphInterface);
    ABIVersion         := VPAGRAPH_ABI_VERSION;
    BackendName        := BackendNameStr;
    BackendVersion     := @BackendVersionBuf[0];

    Init               := @X11Init;
    Shutdown           := @X11Shutdown;
    GetLastError       := @X11GetLastError;
    Present            := @X11Present;
    GraphResult        := @X11GraphResult;
    Suspend            := @X11Suspend;
    Resume             := @X11Resume;

    ClearDevice        := @X11ClearDevice;
    SetViewPort        := @X11SetViewPort;
    GetViewSettings    := @X11GetViewSettings;
    SetColor           := @X11SetColor;
    GetColor           := @X11GetColor;
    SetLineStyle       := @X11SetLineStyle;
    SetFillStyle       := @X11SetFillStyle;
    SetWriteMode       := @X11SetWriteMode;
    PutPixel           := @X11PutPixel;
    GetPixel           := @X11GetPixel;
    Line               := @X11Line;
    LineTo             := @X11LineTo;
    LineRel            := @X11LineRel;
    MoveTo             := @X11MoveTo;
    Rectangle          := @X11Rectangle;
    Bar                := @X11Bar;
    Circle             := @X11Circle;
    Ellipse            := @X11Ellipse;

    ImageSize          := @X11ImageSize;
    GetImage           := @X11GetImage;
    PutImage           := @X11PutImage;

    SetRGBPalette      := @X11SetRGBPalette;
    GetRGBPalette      := @X11GetRGBPalette;
    SetRGBPaletteBlock := @X11SetRGBPaletteBlock;

    OutTextXY          := @X11OutTextXY;
    SetTextStyle       := @X11SetTextStyle;
    SetTextJustify     := @X11SetTextJustify;
    InstallUserFont    := @X11InstallUserFont;

    GetScreenSize      := @X11GetScreenSize;
    SetFullscreen      := @X11SetFullscreen;
    GetWindowSize      := @X11GetWindowSize;

    { T2.11 (PollEvent, GetModifiers, GetMouseState, SetMousePos, ShowMouse)
      queda a nil hasta T5.8. }

    DumpFrame          := @X11DumpFrame;
  end;
  Result := VPAG_OK;
end;

initialization
  LastMessage[0] := #0;
  FillChar(BackendVersionBuf, SizeOf(BackendVersionBuf), 0);
  Move(BackendVersionText[1], BackendVersionBuf[0], Length(BackendVersionText));

end.
